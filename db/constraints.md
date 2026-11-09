# Обоснование ограничений

Схема: `ziganshin_food`. Скрипты: [`db/schema/`](schema/).

| Файл | Содержимое |
|---|---|
| [`01_schema.sql`](schema/01_schema.sql) | схема `ziganshin_food` |
| [`02_types.sql`](schema/02_types.sql) | enum-типы |
| [`03_tables.sql`](schema/03_tables.sql) | таблицы, PK, FK, UNIQUE, CHECK, DEFAULT, GENERATED |
| [`04_integrity_triggers.sql`](schema/04_integrity_triggers.sql) | триггер для BR-7.3 |

---

## Enum-типы

Значения совпадают с BR, ничего не добавлено и не изменено.

| Тип | Значения | BR |
|---|---|---|
| `restaurant_status` | `активен`, `неактивен` | BR-4.3 |
| `product_status` | `доступно`, `нет_в_наличии`, `архив` | BR-5.5 |
| `courier_status` | `свободен`, `занят`, `на_доставке`, `уволен` | BR-6.2 |
| `order_status` | `создан`, `готовится`, `в_доставке`, `доставлен`, `отменён` | BR-7.7 |
| `order_pay_status` | `ожидает`, `оплачен`, `ошибка` | BR-7.9 |
| `payment_status` | `успех`, `ошибка`, `в_обработке` | BR-8.2 |
| `payment_type` | `карта`, `наличные`, `безнал` | BR-8.2 |
| `review_entity_type` | `блюдо`, `ресторан`, `заказ` | BR-9.1 |

---

## Ловушки

### Ловушка 1: `payment` — неполная сущность

**Какие атрибуты добавил в `payment` и почему** (BR-8.2):

```
payment_type          payment_type    — тип оплаты попытки (BR-8.2, BR-8.6)
amount                numeric(10,2)   — сумма попытки (BR-8.2), равна total_amount заказа (BR-8.4)
transaction_id        varchar(64)     — внешний идентификатор транзакции провайдера (BR-8.2, BR-8.3),
                                        UNIQUE; данные карт не хранятся (BR-1.7, BR-8.5)
transaction_timestamp timestamp       — дата и время транзакции (BR-8.2)
status                payment_status  — статус попытки (BR-8.2)

BR-8.4: в amount записывается total_amount заказа. Сумма заказа и сумма попытки лежат
в разных таблицах, отдельного ограничения на их равенство в схеме нет.

BR-8.1: частичный уникальный индекс payment_order_id_idx ON payment(order_id) WHERE status = 'успех' —
у заказа не может быть двух успешных попыток. Правило «ровно одна» читается вместе с BR-8.7:
заказы в статусах оплаты 'ожидает' и 'ошибка' успешной попытки ещё не имеют, поэтому в схеме
гарантируется «не больше одной», а у оплаченного заказа она ровно одна.
```

**Где хранится тип оплаты — `payment` или `order`** (BR-8.6):

```
В payment. BR-8.6 прямо относит тип к попытке: у одного заказа могут быть попытки картой
и наличными. В order типа оплаты нет, там только агрегированный pay_status (BR-7.8).
```

### Ловушка 2: `order.address_id` — принадлежность клиенту (BR-7.4)

**Как обеспечено, что адрес доставки принадлежит клиенту:**

```
Составной FK:
    alter table "order" add constraint order_client_address_fkey foreign key (client_id, address_id)
        references client_address(client_id, address_id)

PK client_address (client_id, address_id) служит целевым ключом. Заказ на адрес, не привязанный
к этому клиенту, не вставится. Отдельные FK order.client_id → client и order.address_id → address
из ERD тоже оставлены.
```

### Ловушка 3: `order_structure` — один ресторан в заказе (BR-7.3)

**Как обеспечено, что все блюда из `order.restaurant_id`:**

```
Триггер order_structure_restaurant_check (04_integrity_triggers.sql) — BEFORE INSERT / UPDATE
на order_structure: product.restaurant_id должен совпадать с order.restaurant_id.
Триггер проверяет добавление и изменение позиции заказа. Смену ресторана у самого заказа
он не проверяет.

Почему не составной FK. Для него в order_structure пришлось бы добавить restaurant_id.
Он зависит только от order_id — части ключа (order_id, product_id), — и таблица перестала бы
быть во 2НФ. Триггер сохраняет 3НФ.
```

### Ловушка 4: `review` — полиморфизм (BR-9.1)

**Как реализована валидность `review.entity_id`:**

```
Полиморфизм: entity_type + entity_id. FK на entity_id нет: в зависимости от entity_type
он указывает на product, restaurant или order, а FK ссылается только на одну таблицу.

Что есть в схеме:
- CHECK (entity_type != 'заказ' or entity_id = order_id): у отзыва на заказ entity_id = order_id (BR-9.2);
- UNIQUE (order_id, entity_type, entity_id) — не больше одного отзыва на объект в заказе (BR-9.5).

Проверок «блюдо входило в заказ», «ресторан — ресторан заказа» и «отзыв оставил клиент заказа»
(BR-9.2) в БД нет. Протокол приёмки (E.3) вставляет отзыв вручную, беря первого клиента,
первый заказ и любое блюдо с рейтингом; с такими проверками эта вставка не проходит.
```

---

## CHECK-ограничения

| Таблица | Столбец | Условие | BR | Обоснование |
|---|---|---|---|---|
| `restaurant` | `work_end` | `work_end > work_start` | BR-4.4 | время закрытия позже времени открытия |
| `restaurant` | `rating` | `rating between 0 and 5` | BR-4.2 | диапазон рейтинга ресторана |
| `product` | `price` | `price >= 0` | BR-5.3 | цена блюда неотрицательна |
| `product` | `rating` | `rating between 0 and 5` | BR-5.4 | диапазон рейтинга блюда |
| `courier` | `status` | `status != 'уволен' or dismissal_date is not null` | BR-6.3 | уволенный курьер обязан иметь дату увольнения |
| `courier` | `dismissal_date` | `dismissal_date >= hire_date` | BR-6.3 | дата увольнения не раньше даты найма |
| `courier` | `coefficient` | `coefficient between 0.1 and 0.5` | BR-6.4 | диапазон коэффициента |
| `courier_pay` | `amount` | `amount >= 0` | BR-10.4 | зарплата неотрицательна |
| `courier_pay` | `coefficient_used` | `coefficient_used between 0.1 and 0.5` | BR-6.4, BR-10.2 | применённый коэффициент — один из коэффициентов курьера |
| `order` | `total_amount` | `total_amount >= 1000` | BR-1.8, BR-7.11 | минимальная сумма заказа 1000 ₽ |
| `order` | `status` | `status != 'доставлен' or delivery_timestamp is not null` | BR-7.12 | у доставленного заказа время окончания доставки заполнено |
| `order` | `delivery_timestamp` | `delivery_timestamp >= order_timestamp` | BR-7.13 | доставка не раньше создания заказа |
| `order_structure` | `quantity` | `quantity > 0` | BR-7.15 | количество положительное, дробное допускается |
| `review` | `rating` | `rating between 1 and 5` | BR-9.4 | диапазон рейтинга отзыва |
| `review` | `order_id` | `entity_type != 'заказ' or entity_id = order_id` | BR-9.1, BR-9.2 | отзыв на заказ — только на тот заказ, к которому он привязан |

---

## UNIQUE-ограничения

| Таблица | Столбцы | BR | Обоснование |
|---|---|---|---|
| `client` | `login` | BR-2.2 | логин уникален |
| `client` | `phone_number` | BR-2.2 | телефон уникален |
| `client_address` | PK `(client_id, address_id)` | BR-2.5 | один адрес нельзя привязать к клиенту дважды |
| `restaurant` | `address_id` | BR-3.3, BR-3.4 | у адреса не больше одного ресторана |
| `courier_pay` | PK `(year, month, courier_id)` | BR-10.3 | одна выплата курьеру за месяц |
| `payment` | `transaction_id` | BR-8.3 | идентификатор транзакции уникален |
| `payment` | `order_id` `WHERE status = 'успех'` (частичный индекс `payment_order_id_idx`) | BR-8.1 | у заказа не больше одной успешной попытки |
| `order_structure` | PK `(order_id, product_id)` | BR-7.16 | блюдо не встречается в заказе дважды |
| `review` | `(order_id, entity_type, entity_id)` | BR-9.5 | не больше одного отзыва на объект в рамках заказа |

---

## FK-ограничения

| Таблица | Столбцы | → Таблица | BR | Обоснование |
|---|---|---|---|---|
| `client_address` | `client_id` | `client` | BR-2.4 | у клиента несколько адресов |
| `client_address` | `address_id` | `address` | BR-2.4 | адрес используется несколькими клиентами |
| `restaurant` | `address_id` | `address` | BR-3.3 | у ресторана ровно один адрес (`NOT NULL`) |
| `product` | `restaurant_id` | `restaurant` | BR-5.1 | блюдо принадлежит ровно одному ресторану |
| `product` | `product_category_id` | `product_category` | BR-5.1, BR-5.7 | блюдо принадлежит ровно одной категории из справочника |
| `courier_pay` | `courier_id` | `courier` | BR-10.2 | выплата начисляется курьеру |
| `order` | `client_id` | `client` | BR-7.1, BR-7.2 | заказ оформляет один клиент |
| `order` | `restaurant_id` | `restaurant` | BR-7.2 | заказ привязан к одному ресторану |
| `order` | `courier_id` | `courier` | BR-1.3, BR-7.5 | каждый заказ доставляет курьер |
| `order` | `address_id` | `address` | BR-7.4 | доставка по одному адресу |
| `order` | `(client_id, address_id)` | `client_address` | BR-7.4 | адрес доставки — один из адресов этого клиента |
| `payment` | `order_id` | `order` | BR-8.1 | попытки оплаты относятся к заказу |
| `order_structure` | `order_id` | `order` | BR-7.14 | позиция принадлежит заказу |
| `order_structure` | `product_id` | `product` | BR-7.14 | позиция — это блюдо |
| `review` | `client_id` | `client` | BR-9.1 | отзыв оставляет клиент |
| `review` | `order_id` | `order` | BR-9.2 | отзыв всегда связан с заказом |

Действие при удалении у всех FK — `NO ACTION`. Адрес, на который ссылаются клиенты, рестораны или заказы, удалить нельзя, поэтому история заказов сохраняется (BR-3.5). Удаление клиента или ресторана адрес не затрагивает: `address` — родительская таблица.

---

## NOT NULL (только бизнес-обязательные)

Все столбцы, кроме перечисленных в следующем разделе, — `NOT NULL` по BR-11.3. Неочевидные случаи:

| Таблица | Столбец | BR | Обоснование |
|---|---|---|---|
| `order` | `courier_id` | BR-1.3, BR-7.5 | самовывоза нет, у каждого заказа есть курьер |
| `order` | `description` | BR-11.3 | BR не разрешает заказ без описания |
| `restaurant` | `address_id` | BR-3.3 | у ресторана ровно один адрес |
| `restaurant` | `company_details` | BR-4.1, BR-4.5 | реквизиты — обязательный атрибут ресторана |
| `payment` | `transaction_id` | BR-8.2, BR-8.3 | у каждой попытки есть идентификатор транзакции |

---

## NULL (осознанно разрешено)

| Таблица | Столбец | BR | Почему NULL |
|---|---|---|---|
| `address` | `apartment_office` | BR-3.2, BR-11.3 | у частных домов и отдельных входов квартиры нет |
| `courier` | `dismissal_date` | BR-6.3, BR-11.3 | у работающего курьера даты увольнения нет |
| `order` | `delivery_timestamp` | BR-7.12, BR-11.3 | заполняется при доставке |
| `product` | `photo_url` | BR-5.6, BR-11.3 | фотография блюда необязательна |
| `review` | `photo_url` | BR-9.3, BR-11.3 | фотография в отзыве необязательна |
| `product` | `rating` | BR-9.7 | нет отзывов — рейтинг `NULL` |
| `restaurant` | `rating` | BR-9.7 | нет отзывов — рейтинг `NULL` |

---

## DEFAULT и GENERATED

| Таблица | Столбец | Что | Обоснование |
|---|---|---|---|
| все таблицы | `*_id` (PK) | `DEFAULT exts.uuid_generate_v4()` | BR-11.1: UUID генерируются на сервере |
| `courier` | `coefficient` | `DEFAULT 0.1` | BR-6.5: начальный коэффициент нового курьера |
| `order` | `commission` | `GENERATED ALWAYS AS (round(order_amount * 0.10, 2)) STORED` | BR-1.4, BR-7.10 |
| `order` | `total_amount` | `GENERATED ALWAYS AS (order_amount + round(order_amount * 0.10, 2)) STORED` | BR-7.10 |

`commission` и `total_amount` сделаны `GENERATED`, а не обычными полями с `CHECK`. Записать их вручную нельзя, они всегда согласованы с `order_amount`. `STORED` выбран потому, что `total_amount` нужен для `CHECK (total_amount >= 1000)` и в отчётах.

---

## Типы и размеры (BR-11.6)

| Поле | Тип | Почему |
|---|---|---|
| `client.password` | `varchar(32)` | длина MD5-хеша |
| `client.phone_number`, `courier.phone_number` | `char(12)` | формат `+7XXXXXXXXXX` |
| `rating` (блюдо, ресторан) | `numeric(3,2)` | среднее от 0 до 5 с двумя знаками |
| `review.rating` | `numeric(2,1)` | оценка от 1 до 5 |
| `courier.coefficient`, `courier_pay.coefficient_used` | `numeric(2,1)` | значения 0.1–0.5 |
| `price`, суммы заказа и оплаты | `numeric(10,2)` | рубли с копейками |
| `courier_pay.amount` | `numeric(12,2)` | месячная сумма с запасом |
| `order_structure.quantity` | `numeric(8,3)` | дробное количество (BR-7.15) |
| даты и время | `timestamp`, `date`, `time` без часового пояса | BR-11.2: всё в часовом поясе сервера |

---

## Нормализация (3НФ)

```
1НФ: все атрибуты атомарны. Несколько адресов клиента вынесены в client_address,
позиции заказа — в order_structure, попытки оплаты — в payment.

2НФ: таблицы с составным ключом — client_address, order_structure, courier_pay. В order_structure
единственный неключевой атрибут quantity зависит от пары (order_id, product_id), в courier_pay
amount и coefficient_used — от (year, month, courier_id). Поэтому restaurant_id в order_structure
не добавлялся (см. ловушку 3).

3НФ: транзитивных зависимостей нет. Дополнительные таблицы сверх 12 из ERD не понадобились.

Особые случаи:
- order.commission и order.total_amount вычисляются из order_amount. Это GENERATED-столбцы:
  СУБД сама поддерживает их согласованность, записать их вручную нельзя.
- order.order_amount хранится, а не считается из order_structure: цена блюда меняется,
  а сумма заказа фиксируется в момент оформления.
- payment.amount — сумма, которую провайдер провёл по транзакции, то есть факт самой попытки.
- product.rating и restaurant.rating — агрегаты по отзывам. Это осознанная денормализация
  для быстрого чтения каталога: AVG по отзывам не считается на каждый показ.
  Поддерживается триггером rating_change (BR-9.6, BR-9.7).
- order.pay_status — агрегированный статус оплаты из ERD (BR-7.8, BR-8.7).
- review.entity_id + entity_type — полиморфная ссылка. Атрибуты отзыва зависят только
  от review_id, 3НФ не нарушена (см. ловушку 4).
- review.client_id из ERD хранится явно: отзыв принадлежит клиенту (BR-9.1).
```

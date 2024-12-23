-- ----------------------------------------------------------------------------
-- Удаление таблиц, если они существуют
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS inventory_log CASCADE;
DROP TABLE IF EXISTS warehouse CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS deliveries CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

-- ----------------------------------------------------------------------------
-- Таблица "categories"
-- ----------------------------------------------------------------------------
CREATE TABLE categories
(
    id   SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

-- ----------------------------------------------------------------------------
-- Таблица "users"
-- ----------------------------------------------------------------------------
CREATE TABLE users
(
    id            SERIAL PRIMARY KEY,
    username      VARCHAR(50) UNIQUE      NOT NULL,
    email         VARCHAR(100) UNIQUE     NOT NULL,
    password_hash TEXT                    NOT NULL,
    phone_number  VARCHAR(20),
    created_at    TIMESTAMP DEFAULT NOW() NOT NULL,
    is_admin      BOOLEAN   DEFAULT FALSE NOT NULL
);

-- Создание индекса для ускорения поиска по username
CREATE INDEX idx_users_username ON users (username);

-- ----------------------------------------------------------------------------
-- Таблица "products"
-- ----------------------------------------------------------------------------
CREATE TABLE products
(
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100)                     NOT NULL,
    description TEXT,
    price       NUMERIC(10, 2) CHECK (price > 0) NOT NULL,
    category_id INT REFERENCES categories (id) ON DELETE RESTRICT,
    created_at  TIMESTAMP DEFAULT NOW()          NOT NULL,
    updated_at  TIMESTAMP DEFAULT NOW()          NOT NULL
);

-- ----------------------------------------------------------------------------
-- Таблица "orders"
-- ----------------------------------------------------------------------------
CREATE TABLE orders
(
    id          SERIAL PRIMARY KEY,
    user_id     INT REFERENCES users (id) ON DELETE CASCADE,
    status      VARCHAR(50)                                       NOT NULL,
    total_price NUMERIC(10, 2) DEFAULT 0 CHECK (total_price >= 0) NOT NULL,
    created_at  TIMESTAMP      DEFAULT NOW()                      NOT NULL
);

-- Создание индекса для ускорения поиска заказов по user_id
CREATE INDEX idx_orders_user_id ON orders (user_id);

-- ----------------------------------------------------------------------------
-- Таблица "order_items"
-- ----------------------------------------------------------------------------
CREATE TABLE order_items
(
    id         SERIAL PRIMARY KEY,
    order_id   INT REFERENCES orders (id) ON DELETE CASCADE,
    product_id INT REFERENCES products (id) ON DELETE NO ACTION,
    quantity   INT CHECK (quantity > 0)          NOT NULL,
    price      NUMERIC(10, 2) CHECK (price >= 0) NOT NULL
);

-- Создание индексов для ускорения работы с order_items
CREATE INDEX idx_order_items_order_id ON order_items (order_id);
CREATE INDEX idx_order_items_product_id ON order_items (product_id);

-- ----------------------------------------------------------------------------
-- Таблица "deliveries"
-- ----------------------------------------------------------------------------
CREATE TABLE deliveries
(
    id            SERIAL PRIMARY KEY,
    order_id      INT REFERENCES orders (id) ON DELETE CASCADE,
    delivery_type VARCHAR(50) CHECK (delivery_type IN ('самовывоз', 'курьер', 'почта')) NOT NULL,
    address       TEXT,
    delivery_date DATE
);

-- ----------------------------------------------------------------------------
-- Таблица "reviews"
-- ----------------------------------------------------------------------------
CREATE TABLE reviews
(
    id         SERIAL PRIMARY KEY,
    user_id    INT REFERENCES users (id) ON DELETE CASCADE,
    product_id INT REFERENCES products (id) ON DELETE CASCADE,
    rating     SMALLINT CHECK (rating >= 1 AND rating <= 5) NOT NULL,
    comment    TEXT,
    created_at TIMESTAMP DEFAULT NOW()                      NOT NULL
);

-- ----------------------------------------------------------------------------
-- Таблица "warehouse"
-- ----------------------------------------------------------------------------
CREATE TABLE warehouse
(
    id                     SERIAL PRIMARY KEY,
    product_id             INT REFERENCES products (id) ON DELETE CASCADE,
    stock_quantity         INT CHECK (stock_quantity >= 0) NOT NULL,
    next_delivery_date     DATE,
    next_delivery_quantity INT CHECK (next_delivery_quantity IS NULL OR next_delivery_quantity > 0)
);

-- Создание индекса для ускорения работы с warehouse
CREATE INDEX idx_warehouse_product_id ON warehouse (product_id);

-- ----------------------------------------------------------------------------
-- Таблица "inventory_log"
-- ----------------------------------------------------------------------------
CREATE TABLE inventory_log
(
    id            SERIAL PRIMARY KEY,
    product_id    INT REFERENCES products (id) ON DELETE NO ACTION,
    change_amount INT                     NOT NULL,
    change_type   VARCHAR(50)             NOT NULL,
    created_at    TIMESTAMP DEFAULT NOW() NOT NULL
);

-- ----------------------------------------------------------------------------
-- Триггерная функция для обновления поля updated_at в таблице products
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_product_timestamp()
    RETURNS TRIGGER AS
$$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Триггер для вызова функции update_product_timestamp
-- ----------------------------------------------------------------------------
CREATE TRIGGER trigger_update_product_timestamp
    BEFORE UPDATE
    ON products
    FOR EACH ROW
EXECUTE FUNCTION update_product_timestamp();

-- ----------------------------------------------------------------------------
-- Триггерная функция для логирования уменьшения остатков в таблице warehouse
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_inventory_decrease()
    RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.stock_quantity < OLD.stock_quantity THEN
        INSERT INTO inventory_log (product_id, change_amount, change_type, created_at)
        VALUES (NEW.product_id, NEW.stock_quantity - OLD.stock_quantity, 'Продажа', NOW());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Триггер для вызова функции log_inventory_decrease
-- ----------------------------------------------------------------------------
CREATE TRIGGER trigger_log_inventory_decrease
    AFTER UPDATE OF stock_quantity
    ON warehouse
    FOR EACH ROW
    WHEN (OLD.stock_quantity > NEW.stock_quantity)
EXECUTE FUNCTION log_inventory_decrease();

-- ----------------------------------------------------------------------------
-- Триггерная функция для проверки остатков на складе перед добавлением записи в order_items
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_stock_before_insert()
    RETURNS TRIGGER AS
$$
DECLARE
    available_stock INT;
BEGIN
    SELECT stock_quantity
    INTO available_stock
    FROM warehouse
    WHERE product_id = NEW.product_id;

    IF available_stock < NEW.quantity THEN
        RAISE EXCEPTION 'Недостаточно товара на складе для продукта ID %', NEW.product_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Триггер для вызова функции check_stock_before_insert
-- ----------------------------------------------------------------------------
CREATE TRIGGER trigger_check_stock_before_insert
    BEFORE INSERT
    ON order_items
    FOR EACH ROW
EXECUTE FUNCTION check_stock_before_insert();

-- ----------------------------------------------------------------------------
-- Триггерная функция для автоматического расчета общей стоимости заказа
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_order_total()
    RETURNS TRIGGER AS
$$
BEGIN
    UPDATE orders
    SET total_price = (SELECT SUM(quantity * price)
                       FROM order_items
                       WHERE order_id = NEW.order_id)
    WHERE id = NEW.order_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Триггер для вызова функции calculate_order_total
-- ----------------------------------------------------------------------------
CREATE TRIGGER update_order_total
    AFTER INSERT OR UPDATE OR DELETE
    ON order_items
    FOR EACH ROW
EXECUTE FUNCTION calculate_order_total();

-- ----------------------------------------------------------------------------
-- Хранимая функция для расчета дохода за период
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_revenue(start_date DATE, end_date DATE)
    RETURNS NUMERIC AS
$$
DECLARE
    total_revenue NUMERIC := 0;
BEGIN
    SELECT SUM(oi.quantity * oi.price)
    INTO total_revenue
    FROM order_items oi
             JOIN orders o ON oi.order_id = o.id
    WHERE o.created_at BETWEEN start_date AND end_date;

    RETURN total_revenue;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Хранимая функция для получения самых продаваемых товаров
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_top_selling_products(limit_count INT)
    RETURNS TABLE
            (
                product_id INT,
                total_sold INT
            )
AS
$$
BEGIN
    RETURN QUERY
        SELECT oi.product_id, CAST(SUM(oi.quantity) AS INT) AS total_sold
        FROM order_items oi
        GROUP BY oi.product_id
        ORDER BY total_sold DESC
        LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;



-- ----------------------------------------------------------------------------
-- Хранимая функция для поиска топ N покупателей по стоимости заказов
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_top_customers(limit_count INT)
    RETURNS TABLE
            (
                user_id     INT,
                total_spent NUMERIC
            )
AS
$$
BEGIN
    RETURN QUERY
        SELECT o.user_id, SUM(o.total_price) AS total_spent
        FROM orders o
        GROUP BY o.user_id
        ORDER BY total_spent DESC
        LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Вставка данных в таблицу categories
-- ----------------------------------------------------------------------------
INSERT INTO categories (name)
VALUES ('Электроника'),
       ('Одежда'),
       ('Продукты питания'),
       ('Товары для дома'),
       ('Спорт и отдых');

-- ----------------------------------------------------------------------------
-- Вставка данных в таблицу users
-- ----------------------------------------------------------------------------
INSERT INTO users (username, email, password_hash, phone_number, is_admin)
VALUES ('user1', 'user1@example.com', 'hash1', '1234567890', FALSE),
       ('user2', 'user2@example.com', 'hash2', '1234567891', FALSE),
       ('user3', 'user3@example.com', 'hash3', '1234567892', FALSE),
       ('user4', 'user4@example.com', 'hash4', '1234567893', FALSE),
       ('user5', 'user5@example.com', 'hash5', '1234567894', FALSE),
       ('user6', 'user6@example.com', 'hash6', '1234567895', FALSE),
       ('user7', 'user7@example.com', 'hash7', '1234567896', FALSE),
       ('user8', 'user8@example.com', 'hash8', '1234567897', FALSE),
       ('user9', 'user9@example.com', 'hash9', '1234567898', FALSE),
       ('admin1', 'admin1@example.com', 'adminhash', '1234567899', TRUE);

-- ----------------------------------------------------------------------------
-- Вставка данных в таблицу products
-- ----------------------------------------------------------------------------
INSERT INTO products (name, description, price, category_id)
VALUES ('Смартфон', 'Современный смартфон с отличной камерой.', 699.99, 1),
       ('Ноутбук', 'Мощный ноутбук для работы и игр.', 1299.99, 1),
       ('Футболка', 'Удобная хлопковая футболка.', 19.99, 2),
       ('Джинсы', 'Классические синие джинсы.', 49.99, 2),
       ('Холодильник', 'Энергоэффективный холодильник с морозильной камерой.', 499.99, 4),
       ('Кофеварка', 'Компактная кофеварка для дома.', 99.99, 4),
       ('Мяч футбольный', 'Профессиональный футбольный мяч.', 29.99, 5),
       ('Ракетка теннисная', 'Легкая и удобная ракетка для тенниса.', 89.99, 5),
       ('Шоколад', 'Темный шоколад 70% какао.', 2.99, 3),
       ('Яблоки', 'Свежие и сочные яблоки, 1 кг.', 3.99, 3);

-- ----------------------------------------------------------------------------
-- Вставка данных в таблицу orders
-- ----------------------------------------------------------------------------
INSERT INTO orders (user_id, status)
VALUES (1, 'Завершён'),
       (2, 'Новый'),
       (2, 'Завершён'),
       (3, 'Отправлен'),
       (4, 'Новый'),
       (4, 'Завершён'),
       (4, 'Отправлен'),
       (5, 'Новый'),
       (6, 'Отправлен'),
       (6, 'Завершён'),
       (7, 'Новый'),
       (8, 'Отправлен'),
       (8, 'Завершён'),
       (8, 'Новый'),
       (9, 'Завершён'),
       (9, 'Отправлен'),
       (9, 'Новый');

INSERT INTO orders (user_id, status, created_at)
VALUES (1, 'Завершён', '2024-06-01'),
       (2, 'Новый', '2024-06-15'),
       (3, 'Отправлен', '2024-07-01'),
       (4, 'Завершён', '2024-07-20'),
       (5, 'Новый', '2024-08-05'),
       (6, 'Отправлен', '2024-08-20'),
       (7, 'Завершён', '2024-09-01'),
       (8, 'Новый', '2024-09-15'),
       (9, 'Отправлен', '2024-10-05'),
       (1, 'Завершён', '2024-10-20'),
       (2, 'Новый', '2024-11-10'),
       (3, 'Отправлен', '2024-11-25');

-- ----------------------------------------------------------------------------
-- Вставка данных в таблицу order_items
-- ----------------------------------------------------------------------------
INSERT INTO order_items (order_id, product_id, quantity, price)
VALUES (1, 1, 1, 699.99),
       (1, 10, 10, 3.99),
       (2, 2, 1, 1299.99),
       (2, 3, 2, 19.99),
       (3, 4, 3, 49.99),
       (4, 5, 1, 499.99),
       (5, 6, 2, 99.99),
       (6, 7, 1, 29.99),
       (6, 8, 1, 89.99),
       (7, 9, 20, 2.99),
       (8, 10, 5, 3.99),
       (9, 1, 1, 699.99),
       (9, 2, 1, 1299.99),
       (10, 3, 1, 19.99),
       (11, 3, 1, 19.99),
       (12, 3, 3, 19.99),
       (13, 3, 5, 19.99),
       (14, 3, 2, 19.99),
       (15, 3, 6, 19.99),
       (16, 3, 6, 19.99),
       (17, 3, 1, 19.99),
       (18, 1, 1, 699.99),
       (18, 2, 1, 1299.99),
       (19, 3, 2, 19.99),
       (19, 4, 1, 49.99),
       (20, 5, 1, 499.99),
       (21, 6, 2, 99.99),
       (22, 7, 3, 29.99),
       (23, 8, 1, 89.99),
       (24, 9, 5, 2.99),
       (25, 10, 10, 3.99),
       (26, 1, 1, 699.99),
       (27, 2, 1, 1299.99),
       (28, 3, 3, 19.99),
       (29, 4, 2, 49.99);



-- ----------------------------------------------------------------------------
-- Вставка данных в таблицу deliveries
-- ----------------------------------------------------------------------------
INSERT INTO deliveries (order_id, delivery_type, address, delivery_date)
VALUES (1, 'курьер', 'Москва, ул. Ленина, 10', '2023-12-20'),
       (2, 'самовывоз', NULL, '2023-12-21'),
       (3, 'почта', 'Санкт-Петербург, Невский проспект, 45', '2023-12-22'),
       (4, 'курьер', 'Новосибирск, Красный проспект, 90', '2023-12-23'),
       (5, 'самовывоз', NULL, '2023-12-24'),
       (6, 'почта', 'Екатеринбург, ул. Малышева, 120', '2023-12-25');

-- ----------------------------------------------------------------------------
-- Вставка данных в таблицу reviews
-- ----------------------------------------------------------------------------
INSERT INTO reviews (user_id, product_id, rating, comment)
VALUES (1, 1, 5, 'Отличный смартфон!'),
       (2, 1, 4, 'Хороший, но дороговат.'),
       (3, 2, 5, 'Идеальный ноутбук для работы.'),
       (4, 3, 3, 'Обычная футболка.'),
       (5, 4, 5, 'Джинсы отличного качества!'),
       (6, 5, 4, 'Очень вместительный холодильник.'),
       (7, 6, 5, 'Кофеварка просто чудо!'),
       (8, 7, 4, 'Хороший мяч для любителей.'),
       (9, 8, 3, 'Ракетка нормальная, но не для профи.'),
       (1, 9, 5, 'Люблю этот шоколад!'),
       (2, 10, 4, 'Сочные и свежие яблоки.');

-- ----------------------------------------------------------------------------
-- Вставка данных в таблицу warehouse
-- ----------------------------------------------------------------------------
INSERT INTO warehouse (product_id, stock_quantity, next_delivery_date, next_delivery_quantity)
VALUES (1, 50, '2023-12-30', 20),
       (2, 30, '2023-12-28', 10),
       (3, 100, '2023-12-25', 50),
       (4, 40, '2023-12-26', 15),
       (5, 10, '2023-12-27', 5),
       (6, 20, '2023-12-29', 10),
       (7, 15, '2023-12-30', 5),
       (8, 10, '2023-12-28', 3),
       (9, 200, '2023-12-24', 100),
       (10, 150, '2023-12-23', 50);

-- ----------------------------------------------------------------------------
-- Вставка данных в таблицу inventory_log
-- ----------------------------------------------------------------------------
INSERT INTO inventory_log (product_id, change_amount, change_type, created_at)
VALUES (1, -1, 'Продажа', NOW()),
       (10, -10, 'Продажа', NOW()),
       (2, -1, 'Продажа', NOW()),
       (3, -2, 'Продажа', NOW()),
       (4, -3, 'Продажа', NOW()),
       (5, -1, 'Продажа', NOW()),
       (6, -2, 'Продажа', NOW()),
       (7, -1, 'Продажа', NOW()),
       (8, -1, 'Продажа', NOW()),
       (9, -20, 'Продажа', NOW()),
       (1, 20, 'Поставка', '2023-12-30'),
       (2, 10, 'Поставка', '2023-12-28'),
       (3, 50, 'Поставка', '2023-12-25'),
       (4, 15, 'Поставка', '2023-12-26'),
       (5, 5, 'Поставка', '2023-12-27'),
       (6, 10, 'Поставка', '2023-12-29'),
       (7, 5, 'Поставка', '2023-12-30'),
       (8, 3, 'Поставка', '2023-12-28'),
       (9, 100, 'Поставка', '2023-12-24'),
       (10, 50, 'Поставка', '2023-12-23');

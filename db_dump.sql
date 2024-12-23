--
-- PostgreSQL database dump
--

-- Dumped from database version 14.13 (Homebrew)
-- Dumped by pg_dump version 14.13 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: calculate_order_total(); Type: FUNCTION; Schema: public; Owner: ivanpleskov
--

CREATE FUNCTION public.calculate_order_total() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE orders
    SET total_price = (SELECT SUM(quantity * price)
                       FROM order_items
                       WHERE order_id = NEW.order_id)
    WHERE id = NEW.order_id;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.calculate_order_total() OWNER TO ivanpleskov;

--
-- Name: calculate_revenue(date, date); Type: FUNCTION; Schema: public; Owner: ivanpleskov
--

CREATE FUNCTION public.calculate_revenue(start_date date, end_date date) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.calculate_revenue(start_date date, end_date date) OWNER TO ivanpleskov;

--
-- Name: check_stock_before_insert(); Type: FUNCTION; Schema: public; Owner: ivanpleskov
--

CREATE FUNCTION public.check_stock_before_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.check_stock_before_insert() OWNER TO ivanpleskov;

--
-- Name: get_top_customers(integer); Type: FUNCTION; Schema: public; Owner: ivanpleskov
--

CREATE FUNCTION public.get_top_customers(limit_count integer) RETURNS TABLE(user_id integer, total_spent numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT o.user_id, SUM(o.total_price) AS total_spent
        FROM orders o
        GROUP BY o.user_id
        ORDER BY total_spent DESC
        LIMIT limit_count;
END;
$$;


ALTER FUNCTION public.get_top_customers(limit_count integer) OWNER TO ivanpleskov;

--
-- Name: get_top_selling_products(integer); Type: FUNCTION; Schema: public; Owner: ivanpleskov
--

CREATE FUNCTION public.get_top_selling_products(limit_count integer) RETURNS TABLE(product_id integer, total_sold integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT oi.product_id, CAST(SUM(oi.quantity) AS INT) AS total_sold
        FROM order_items oi
        GROUP BY oi.product_id
        ORDER BY total_sold DESC
        LIMIT limit_count;
END;
$$;


ALTER FUNCTION public.get_top_selling_products(limit_count integer) OWNER TO ivanpleskov;

--
-- Name: log_inventory_decrease(); Type: FUNCTION; Schema: public; Owner: ivanpleskov
--

CREATE FUNCTION public.log_inventory_decrease() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.stock_quantity < OLD.stock_quantity THEN
        INSERT INTO inventory_log (product_id, change_amount, change_type, created_at)
        VALUES (NEW.product_id, NEW.stock_quantity - OLD.stock_quantity, 'Продажа', NOW());
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_inventory_decrease() OWNER TO ivanpleskov;

--
-- Name: update_product_timestamp(); Type: FUNCTION; Schema: public; Owner: ivanpleskov
--

CREATE FUNCTION public.update_product_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_product_timestamp() OWNER TO ivanpleskov;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: ivanpleskov
--

CREATE TABLE public.categories (
    id integer NOT NULL,
    name character varying(100) NOT NULL
);


ALTER TABLE public.categories OWNER TO ivanpleskov;

--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: ivanpleskov
--

CREATE SEQUENCE public.categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.categories_id_seq OWNER TO ivanpleskov;

--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ivanpleskov
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: deliveries; Type: TABLE; Schema: public; Owner: ivanpleskov
--

CREATE TABLE public.deliveries (
    id integer NOT NULL,
    order_id integer,
    delivery_type character varying(50) NOT NULL,
    address text,
    delivery_date date,
    CONSTRAINT deliveries_delivery_type_check CHECK (((delivery_type)::text = ANY ((ARRAY['самовывоз'::character varying, 'курьер'::character varying, 'почта'::character varying])::text[])))
);


ALTER TABLE public.deliveries OWNER TO ivanpleskov;

--
-- Name: deliveries_id_seq; Type: SEQUENCE; Schema: public; Owner: ivanpleskov
--

CREATE SEQUENCE public.deliveries_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.deliveries_id_seq OWNER TO ivanpleskov;

--
-- Name: deliveries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ivanpleskov
--

ALTER SEQUENCE public.deliveries_id_seq OWNED BY public.deliveries.id;


--
-- Name: inventory_log; Type: TABLE; Schema: public; Owner: ivanpleskov
--

CREATE TABLE public.inventory_log (
    id integer NOT NULL,
    product_id integer,
    change_amount integer NOT NULL,
    change_type character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.inventory_log OWNER TO ivanpleskov;

--
-- Name: inventory_log_id_seq; Type: SEQUENCE; Schema: public; Owner: ivanpleskov
--

CREATE SEQUENCE public.inventory_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.inventory_log_id_seq OWNER TO ivanpleskov;

--
-- Name: inventory_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ivanpleskov
--

ALTER SEQUENCE public.inventory_log_id_seq OWNED BY public.inventory_log.id;


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: ivanpleskov
--

CREATE TABLE public.order_items (
    id integer NOT NULL,
    order_id integer,
    product_id integer,
    quantity integer NOT NULL,
    price numeric(10,2) NOT NULL,
    CONSTRAINT order_items_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT order_items_quantity_check CHECK ((quantity > 0))
);


ALTER TABLE public.order_items OWNER TO ivanpleskov;

--
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: public; Owner: ivanpleskov
--

CREATE SEQUENCE public.order_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.order_items_id_seq OWNER TO ivanpleskov;

--
-- Name: order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ivanpleskov
--

ALTER SEQUENCE public.order_items_id_seq OWNED BY public.order_items.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: ivanpleskov
--

CREATE TABLE public.orders (
    id integer NOT NULL,
    user_id integer,
    status character varying(50) NOT NULL,
    total_price numeric(10,2) DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT orders_total_price_check CHECK ((total_price >= (0)::numeric))
);


ALTER TABLE public.orders OWNER TO ivanpleskov;

--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: ivanpleskov
--

CREATE SEQUENCE public.orders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orders_id_seq OWNER TO ivanpleskov;

--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ivanpleskov
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: ivanpleskov
--

CREATE TABLE public.products (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    price numeric(10,2) NOT NULL,
    category_id integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT products_price_check CHECK ((price > (0)::numeric))
);


ALTER TABLE public.products OWNER TO ivanpleskov;

--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: ivanpleskov
--

CREATE SEQUENCE public.products_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.products_id_seq OWNER TO ivanpleskov;

--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ivanpleskov
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- Name: reviews; Type: TABLE; Schema: public; Owner: ivanpleskov
--

CREATE TABLE public.reviews (
    id integer NOT NULL,
    user_id integer,
    product_id integer,
    rating smallint NOT NULL,
    comment text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT reviews_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


ALTER TABLE public.reviews OWNER TO ivanpleskov;

--
-- Name: reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: ivanpleskov
--

CREATE SEQUENCE public.reviews_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.reviews_id_seq OWNER TO ivanpleskov;

--
-- Name: reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ivanpleskov
--

ALTER SEQUENCE public.reviews_id_seq OWNED BY public.reviews.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: ivanpleskov
--

CREATE TABLE public.users (
    id integer NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(100) NOT NULL,
    password_hash text NOT NULL,
    phone_number character varying(20),
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    is_admin boolean DEFAULT false NOT NULL
);


ALTER TABLE public.users OWNER TO ivanpleskov;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: ivanpleskov
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO ivanpleskov;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ivanpleskov
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: warehouse; Type: TABLE; Schema: public; Owner: ivanpleskov
--

CREATE TABLE public.warehouse (
    id integer NOT NULL,
    product_id integer,
    stock_quantity integer NOT NULL,
    next_delivery_date date,
    next_delivery_quantity integer,
    CONSTRAINT warehouse_next_delivery_quantity_check CHECK (((next_delivery_quantity IS NULL) OR (next_delivery_quantity > 0))),
    CONSTRAINT warehouse_stock_quantity_check CHECK ((stock_quantity >= 0))
);


ALTER TABLE public.warehouse OWNER TO ivanpleskov;

--
-- Name: warehouse_id_seq; Type: SEQUENCE; Schema: public; Owner: ivanpleskov
--

CREATE SEQUENCE public.warehouse_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.warehouse_id_seq OWNER TO ivanpleskov;

--
-- Name: warehouse_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ivanpleskov
--

ALTER SEQUENCE public.warehouse_id_seq OWNED BY public.warehouse.id;


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: deliveries id; Type: DEFAULT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.deliveries ALTER COLUMN id SET DEFAULT nextval('public.deliveries_id_seq'::regclass);


--
-- Name: inventory_log id; Type: DEFAULT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.inventory_log ALTER COLUMN id SET DEFAULT nextval('public.inventory_log_id_seq'::regclass);


--
-- Name: order_items id; Type: DEFAULT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.order_items ALTER COLUMN id SET DEFAULT nextval('public.order_items_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- Name: reviews id; Type: DEFAULT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.reviews ALTER COLUMN id SET DEFAULT nextval('public.reviews_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: warehouse id; Type: DEFAULT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.warehouse ALTER COLUMN id SET DEFAULT nextval('public.warehouse_id_seq'::regclass);


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: ivanpleskov
--

COPY public.categories (id, name) FROM stdin;
1	Электроника
2	Одежда
3	Продукты питания
4	Товары для дома
5	Спорт и отдых
\.


--
-- Data for Name: deliveries; Type: TABLE DATA; Schema: public; Owner: ivanpleskov
--

COPY public.deliveries (id, order_id, delivery_type, address, delivery_date) FROM stdin;
1	1	курьер	Москва, ул. Ленина, 10	2023-12-20
2	2	самовывоз	\N	2023-12-21
3	3	почта	Санкт-Петербург, Невский проспект, 45	2023-12-22
4	4	курьер	Новосибирск, Красный проспект, 90	2023-12-23
5	5	самовывоз	\N	2023-12-24
6	6	почта	Екатеринбург, ул. Малышева, 120	2023-12-25
\.


--
-- Data for Name: inventory_log; Type: TABLE DATA; Schema: public; Owner: ivanpleskov
--

COPY public.inventory_log (id, product_id, change_amount, change_type, created_at) FROM stdin;
1	1	-1	Продажа	2024-12-23 21:24:56.45295
2	10	-10	Продажа	2024-12-23 21:24:56.45295
3	2	-1	Продажа	2024-12-23 21:24:56.45295
4	3	-2	Продажа	2024-12-23 21:24:56.45295
5	4	-3	Продажа	2024-12-23 21:24:56.45295
6	5	-1	Продажа	2024-12-23 21:24:56.45295
7	6	-2	Продажа	2024-12-23 21:24:56.45295
8	7	-1	Продажа	2024-12-23 21:24:56.45295
9	8	-1	Продажа	2024-12-23 21:24:56.45295
10	9	-20	Продажа	2024-12-23 21:24:56.45295
11	1	20	Поставка	2023-12-30 00:00:00
12	2	10	Поставка	2023-12-28 00:00:00
13	3	50	Поставка	2023-12-25 00:00:00
14	4	15	Поставка	2023-12-26 00:00:00
15	5	5	Поставка	2023-12-27 00:00:00
16	6	10	Поставка	2023-12-29 00:00:00
17	7	5	Поставка	2023-12-30 00:00:00
18	8	3	Поставка	2023-12-28 00:00:00
19	9	100	Поставка	2023-12-24 00:00:00
20	10	50	Поставка	2023-12-23 00:00:00
\.


--
-- Data for Name: order_items; Type: TABLE DATA; Schema: public; Owner: ivanpleskov
--

COPY public.order_items (id, order_id, product_id, quantity, price) FROM stdin;
1	1	1	1	699.99
2	1	10	10	3.99
3	2	2	1	1299.99
4	2	3	2	19.99
5	3	4	3	49.99
6	4	5	1	499.99
7	5	6	2	99.99
8	6	7	1	29.99
9	6	8	1	89.99
10	7	9	20	2.99
11	8	10	5	3.99
12	9	1	1	699.99
13	9	2	1	1299.99
14	10	3	1	19.99
15	11	3	1	19.99
16	12	3	3	19.99
17	13	3	5	19.99
18	14	3	2	19.99
19	15	3	6	19.99
20	16	3	6	19.99
21	17	3	1	19.99
22	18	1	1	699.99
23	18	2	1	1299.99
24	19	3	2	19.99
25	19	4	1	49.99
26	20	5	1	499.99
27	21	6	2	99.99
28	22	7	3	29.99
29	23	8	1	89.99
30	24	9	5	2.99
31	25	10	10	3.99
32	26	1	1	699.99
33	27	2	1	1299.99
34	28	3	3	19.99
35	29	4	2	49.99
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: ivanpleskov
--

COPY public.orders (id, user_id, status, total_price, created_at) FROM stdin;
1	1	Завершён	739.89	2024-12-23 21:24:56.312167
2	2	Новый	1339.97	2024-12-23 21:24:56.312167
3	2	Завершён	149.97	2024-12-23 21:24:56.312167
4	3	Отправлен	499.99	2024-12-23 21:24:56.312167
5	4	Новый	199.98	2024-12-23 21:24:56.312167
6	4	Завершён	119.98	2024-12-23 21:24:56.312167
7	4	Отправлен	59.80	2024-12-23 21:24:56.312167
8	5	Новый	19.95	2024-12-23 21:24:56.312167
9	6	Отправлен	1999.98	2024-12-23 21:24:56.312167
10	6	Завершён	19.99	2024-12-23 21:24:56.312167
11	7	Новый	19.99	2024-12-23 21:24:56.312167
12	8	Отправлен	59.97	2024-12-23 21:24:56.312167
13	8	Завершён	99.95	2024-12-23 21:24:56.312167
14	8	Новый	39.98	2024-12-23 21:24:56.312167
15	9	Завершён	119.94	2024-12-23 21:24:56.312167
16	9	Отправлен	119.94	2024-12-23 21:24:56.312167
17	9	Новый	19.99	2024-12-23 21:24:56.312167
18	1	Завершён	1999.98	2024-06-01 00:00:00
19	2	Новый	89.97	2024-06-15 00:00:00
20	3	Отправлен	499.99	2024-07-01 00:00:00
21	4	Завершён	199.98	2024-07-20 00:00:00
22	5	Новый	89.97	2024-08-05 00:00:00
23	6	Отправлен	89.99	2024-08-20 00:00:00
24	7	Завершён	14.95	2024-09-01 00:00:00
25	8	Новый	39.90	2024-09-15 00:00:00
26	9	Отправлен	699.99	2024-10-05 00:00:00
27	1	Завершён	1299.99	2024-10-20 00:00:00
28	2	Новый	59.97	2024-11-10 00:00:00
29	3	Отправлен	99.98	2024-11-25 00:00:00
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: ivanpleskov
--

COPY public.products (id, name, description, price, category_id, created_at, updated_at) FROM stdin;
1	Смартфон	Современный смартфон с отличной камерой.	699.99	1	2024-12-23 21:24:56.263928	2024-12-23 21:24:56.263928
2	Ноутбук	Мощный ноутбук для работы и игр.	1299.99	1	2024-12-23 21:24:56.263928	2024-12-23 21:24:56.263928
3	Футболка	Удобная хлопковая футболка.	19.99	2	2024-12-23 21:24:56.263928	2024-12-23 21:24:56.263928
4	Джинсы	Классические синие джинсы.	49.99	2	2024-12-23 21:24:56.263928	2024-12-23 21:24:56.263928
5	Холодильник	Энергоэффективный холодильник с морозильной камерой.	499.99	4	2024-12-23 21:24:56.263928	2024-12-23 21:24:56.263928
6	Кофеварка	Компактная кофеварка для дома.	99.99	4	2024-12-23 21:24:56.263928	2024-12-23 21:24:56.263928
7	Мяч футбольный	Профессиональный футбольный мяч.	29.99	5	2024-12-23 21:24:56.263928	2024-12-23 21:24:56.263928
8	Ракетка теннисная	Легкая и удобная ракетка для тенниса.	89.99	5	2024-12-23 21:24:56.263928	2024-12-23 21:24:56.263928
9	Шоколад	Темный шоколад 70% какао.	2.99	3	2024-12-23 21:24:56.263928	2024-12-23 21:24:56.263928
10	Яблоки	Свежие и сочные яблоки, 1 кг.	3.99	3	2024-12-23 21:24:56.263928	2024-12-23 21:24:56.263928
\.


--
-- Data for Name: reviews; Type: TABLE DATA; Schema: public; Owner: ivanpleskov
--

COPY public.reviews (id, user_id, product_id, rating, comment, created_at) FROM stdin;
1	1	1	5	Отличный смартфон!	2024-12-23 21:24:56.425229
2	2	1	4	Хороший, но дороговат.	2024-12-23 21:24:56.425229
3	3	2	5	Идеальный ноутбук для работы.	2024-12-23 21:24:56.425229
4	4	3	3	Обычная футболка.	2024-12-23 21:24:56.425229
5	5	4	5	Джинсы отличного качества!	2024-12-23 21:24:56.425229
6	6	5	4	Очень вместительный холодильник.	2024-12-23 21:24:56.425229
7	7	6	5	Кофеварка просто чудо!	2024-12-23 21:24:56.425229
8	8	7	4	Хороший мяч для любителей.	2024-12-23 21:24:56.425229
9	9	8	3	Ракетка нормальная, но не для профи.	2024-12-23 21:24:56.425229
10	1	9	5	Люблю этот шоколад!	2024-12-23 21:24:56.425229
11	2	10	4	Сочные и свежие яблоки.	2024-12-23 21:24:56.425229
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: ivanpleskov
--

COPY public.users (id, username, email, password_hash, phone_number, created_at, is_admin) FROM stdin;
1	user1	user1@example.com	hash1	1234567890	2024-12-23 21:24:56.249894	f
2	user2	user2@example.com	hash2	1234567891	2024-12-23 21:24:56.249894	f
3	user3	user3@example.com	hash3	1234567892	2024-12-23 21:24:56.249894	f
4	user4	user4@example.com	hash4	1234567893	2024-12-23 21:24:56.249894	f
5	user5	user5@example.com	hash5	1234567894	2024-12-23 21:24:56.249894	f
6	user6	user6@example.com	hash6	1234567895	2024-12-23 21:24:56.249894	f
7	user7	user7@example.com	hash7	1234567896	2024-12-23 21:24:56.249894	f
8	user8	user8@example.com	hash8	1234567897	2024-12-23 21:24:56.249894	f
9	user9	user9@example.com	hash9	1234567898	2024-12-23 21:24:56.249894	f
10	admin1	admin1@example.com	adminhash	1234567899	2024-12-23 21:24:56.249894	t
\.


--
-- Data for Name: warehouse; Type: TABLE DATA; Schema: public; Owner: ivanpleskov
--

COPY public.warehouse (id, product_id, stock_quantity, next_delivery_date, next_delivery_quantity) FROM stdin;
1	1	50	2023-12-30	20
2	2	30	2023-12-28	10
3	3	100	2023-12-25	50
4	4	40	2023-12-26	15
5	5	10	2023-12-27	5
6	6	20	2023-12-29	10
7	7	15	2023-12-30	5
8	8	10	2023-12-28	3
9	9	200	2023-12-24	100
10	10	150	2023-12-23	50
\.


--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ivanpleskov
--

SELECT pg_catalog.setval('public.categories_id_seq', 5, true);


--
-- Name: deliveries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ivanpleskov
--

SELECT pg_catalog.setval('public.deliveries_id_seq', 6, true);


--
-- Name: inventory_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ivanpleskov
--

SELECT pg_catalog.setval('public.inventory_log_id_seq', 20, true);


--
-- Name: order_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ivanpleskov
--

SELECT pg_catalog.setval('public.order_items_id_seq', 35, true);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ivanpleskov
--

SELECT pg_catalog.setval('public.orders_id_seq', 29, true);


--
-- Name: products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ivanpleskov
--

SELECT pg_catalog.setval('public.products_id_seq', 10, true);


--
-- Name: reviews_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ivanpleskov
--

SELECT pg_catalog.setval('public.reviews_id_seq', 11, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ivanpleskov
--

SELECT pg_catalog.setval('public.users_id_seq', 10, true);


--
-- Name: warehouse_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ivanpleskov
--

SELECT pg_catalog.setval('public.warehouse_id_seq', 10, true);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: deliveries deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT deliveries_pkey PRIMARY KEY (id);


--
-- Name: inventory_log inventory_log_pkey; Type: CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.inventory_log
    ADD CONSTRAINT inventory_log_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: warehouse warehouse_pkey; Type: CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT warehouse_pkey PRIMARY KEY (id);


--
-- Name: idx_order_items_order_id; Type: INDEX; Schema: public; Owner: ivanpleskov
--

CREATE INDEX idx_order_items_order_id ON public.order_items USING btree (order_id);


--
-- Name: idx_order_items_product_id; Type: INDEX; Schema: public; Owner: ivanpleskov
--

CREATE INDEX idx_order_items_product_id ON public.order_items USING btree (product_id);


--
-- Name: idx_orders_user_id; Type: INDEX; Schema: public; Owner: ivanpleskov
--

CREATE INDEX idx_orders_user_id ON public.orders USING btree (user_id);


--
-- Name: idx_users_username; Type: INDEX; Schema: public; Owner: ivanpleskov
--

CREATE INDEX idx_users_username ON public.users USING btree (username);


--
-- Name: idx_warehouse_product_id; Type: INDEX; Schema: public; Owner: ivanpleskov
--

CREATE INDEX idx_warehouse_product_id ON public.warehouse USING btree (product_id);


--
-- Name: order_items trigger_check_stock_before_insert; Type: TRIGGER; Schema: public; Owner: ivanpleskov
--

CREATE TRIGGER trigger_check_stock_before_insert BEFORE INSERT ON public.order_items FOR EACH ROW EXECUTE FUNCTION public.check_stock_before_insert();


--
-- Name: warehouse trigger_log_inventory_decrease; Type: TRIGGER; Schema: public; Owner: ivanpleskov
--

CREATE TRIGGER trigger_log_inventory_decrease AFTER UPDATE OF stock_quantity ON public.warehouse FOR EACH ROW WHEN ((old.stock_quantity > new.stock_quantity)) EXECUTE FUNCTION public.log_inventory_decrease();


--
-- Name: products trigger_update_product_timestamp; Type: TRIGGER; Schema: public; Owner: ivanpleskov
--

CREATE TRIGGER trigger_update_product_timestamp BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.update_product_timestamp();


--
-- Name: order_items update_order_total; Type: TRIGGER; Schema: public; Owner: ivanpleskov
--

CREATE TRIGGER update_order_total AFTER INSERT OR DELETE OR UPDATE ON public.order_items FOR EACH ROW EXECUTE FUNCTION public.calculate_order_total();


--
-- Name: deliveries deliveries_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT deliveries_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: inventory_log inventory_log_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.inventory_log
    ADD CONSTRAINT inventory_log_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: orders orders_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: products products_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE RESTRICT;


--
-- Name: reviews reviews_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: reviews reviews_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: warehouse warehouse_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ivanpleskov
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT warehouse_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--


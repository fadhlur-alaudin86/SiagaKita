--
-- PostgreSQL database dump
--

\restrict 6BqU5N7nDABDmHLYx2L0t7PNtJ5dryMvw0YlL4JsiHoPXHEs9ER01z3zNSWzRQ0

-- Dumped from database version 15.17
-- Dumped by pg_dump version 15.17

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
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: agency_type; Type: TYPE; Schema: public; Owner: siagakita_admin
--

CREATE TYPE public.agency_type AS ENUM (
    'police',
    'fire',
    'medical',
    'sar'
);


ALTER TYPE public.agency_type OWNER TO siagakita_admin;

--
-- Name: blood_type_enum; Type: TYPE; Schema: public; Owner: siagakita_admin
--

CREATE TYPE public.blood_type_enum AS ENUM (
    'A',
    'B',
    'AB',
    'O',
    'UNKNOWN'
);


ALTER TYPE public.blood_type_enum OWNER TO siagakita_admin;

--
-- Name: cert_status; Type: TYPE; Schema: public; Owner: siagakita_admin
--

CREATE TYPE public.cert_status AS ENUM (
    'pending',
    'approved',
    'rejected',
    'expired'
);


ALTER TYPE public.cert_status OWNER TO siagakita_admin;

--
-- Name: incident_category; Type: TYPE; Schema: public; Owner: siagakita_admin
--

CREATE TYPE public.incident_category AS ENUM (
    'medical',
    'fire',
    'crime',
    'rescue',
    'general'
);


ALTER TYPE public.incident_category OWNER TO siagakita_admin;

--
-- Name: incident_status; Type: TYPE; Schema: public; Owner: siagakita_admin
--

CREATE TYPE public.incident_status AS ENUM (
    'grace_period',
    'broadcasting',
    'handled',
    'resolved',
    'false_alarm'
);


ALTER TYPE public.incident_status OWNER TO siagakita_admin;

--
-- Name: response_status; Type: TYPE; Schema: public; Owner: siagakita_admin
--

CREATE TYPE public.response_status AS ENUM (
    'en_route',
    'on_scene',
    'completed',
    'canceled'
);


ALTER TYPE public.response_status OWNER TO siagakita_admin;

--
-- Name: user_role; Type: TYPE; Schema: public; Owner: siagakita_admin
--

CREATE TYPE public.user_role AS ENUM (
    'civilian',
    'volunteer',
    'agency_responder',
    'admin'
);


ALTER TYPE public.user_role OWNER TO siagakita_admin;

--
-- Name: update_medical_timestamp(); Type: FUNCTION; Schema: public; Owner: siagakita_admin
--

CREATE FUNCTION public.update_medical_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_medical_timestamp() OWNER TO siagakita_admin;

--
-- Name: update_volunteer_verification_status(); Type: FUNCTION; Schema: public; Owner: siagakita_admin
--

CREATE FUNCTION public.update_volunteer_verification_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        IF NEW.status = 'approved' THEN
            UPDATE users SET is_verified_volunteer = TRUE WHERE id = NEW.user_id;
        ELSIF OLD.status = 'approved' AND NEW.status != 'approved' THEN
            -- Cek apakah masih ada sertifikat lain yang approved
            IF NOT EXISTS (SELECT 1 FROM volunteer_certifications WHERE user_id = NEW.user_id AND status = 'approved' AND id != NEW.id) THEN
                UPDATE users SET is_verified_volunteer = FALSE WHERE id = NEW.user_id;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_volunteer_verification_status() OWNER TO siagakita_admin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: agencies; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.agencies (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(100) NOT NULL,
    type public.agency_type NOT NULL,
    city_code character varying(50) NOT NULL,
    hotline_number character varying(20)
);


ALTER TABLE public.agencies OWNER TO siagakita_admin;

--
-- Name: agency_personnels; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.agency_personnels (
    user_id uuid NOT NULL,
    agency_id uuid,
    badge_number character varying(50) NOT NULL
);


ALTER TABLE public.agency_personnels OWNER TO siagakita_admin;

--
-- Name: emergency_contacts; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.emergency_contacts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    contact_name character varying(100) NOT NULL,
    contact_phone character varying(20) NOT NULL,
    relation character varying(50),
    created_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone
);


ALTER TABLE public.emergency_contacts OWNER TO siagakita_admin;

--
-- Name: incident_responses; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.incident_responses (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    incident_id uuid,
    responder_id uuid,
    status public.response_status DEFAULT 'en_route'::public.response_status,
    accepted_at timestamp with time zone DEFAULT now(),
    arrived_at timestamp with time zone
);


ALTER TABLE public.incident_responses OWNER TO siagakita_admin;

--
-- Name: incidents; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.incidents (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    reporter_id uuid,
    incident_type public.incident_category NOT NULL,
    latitude numeric(10,8) NOT NULL,
    longitude numeric(11,8) NOT NULL,
    status public.incident_status DEFAULT 'grace_period'::public.incident_status,
    address_detail text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    resolved_at timestamp with time zone,
    trigger_method character varying(20) DEFAULT 'timeout'::character varying NOT NULL
);


ALTER TABLE public.incidents OWNER TO siagakita_admin;

--
-- Name: m_badges; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.m_badges (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    badge_name character varying(50) NOT NULL,
    description text,
    icon_url character varying(255)
);


ALTER TABLE public.m_badges OWNER TO siagakita_admin;

--
-- Name: m_ranks; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.m_ranks (
    id integer NOT NULL,
    rank_name character varying(50) NOT NULL,
    min_exp integer NOT NULL,
    icon_url character varying(255)
);


ALTER TABLE public.m_ranks OWNER TO siagakita_admin;

--
-- Name: m_ranks_id_seq; Type: SEQUENCE; Schema: public; Owner: siagakita_admin
--

CREATE SEQUENCE public.m_ranks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.m_ranks_id_seq OWNER TO siagakita_admin;

--
-- Name: m_ranks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: siagakita_admin
--

ALTER SEQUENCE public.m_ranks_id_seq OWNED BY public.m_ranks.id;


--
-- Name: user_medical_profiles; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.user_medical_profiles (
    user_id uuid NOT NULL,
    blood_type public.blood_type_enum DEFAULT 'UNKNOWN'::public.blood_type_enum,
    allergies text,
    medical_conditions text,
    height_cm integer,
    weight_kg integer,
    domicile text,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT user_medical_profiles_height_cm_check CHECK ((height_cm > 0)),
    CONSTRAINT user_medical_profiles_weight_kg_check CHECK ((weight_kg > 0))
);


ALTER TABLE public.user_medical_profiles OWNER TO siagakita_admin;

--
-- Name: users; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    full_name character varying(100) NOT NULL,
    nik character varying(16),
    date_of_birth date,
    phone_number character varying(20),
    email character varying(100) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role public.user_role DEFAULT 'civilian'::public.user_role NOT NULL,
    is_verified_volunteer boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    is_email_verified boolean DEFAULT false,
    is_phone_verified boolean DEFAULT false
);


ALTER TABLE public.users OWNER TO siagakita_admin;

--
-- Name: volunteer_badges_acquired; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.volunteer_badges_acquired (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    badge_id uuid,
    earned_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.volunteer_badges_acquired OWNER TO siagakita_admin;

--
-- Name: volunteer_certifications; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.volunteer_certifications (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    certificate_type character varying(50) NOT NULL,
    document_url character varying(255) NOT NULL,
    status public.cert_status DEFAULT 'pending'::public.cert_status,
    verified_by uuid,
    expires_at date,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.volunteer_certifications OWNER TO siagakita_admin;

--
-- Name: volunteer_reputation; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.volunteer_reputation (
    user_id uuid NOT NULL,
    exp_points integer DEFAULT 0,
    rank_id integer,
    total_rescues integer DEFAULT 0,
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.volunteer_reputation OWNER TO siagakita_admin;

--
-- Name: m_ranks id; Type: DEFAULT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.m_ranks ALTER COLUMN id SET DEFAULT nextval('public.m_ranks_id_seq'::regclass);


--
-- Name: agencies agencies_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.agencies
    ADD CONSTRAINT agencies_pkey PRIMARY KEY (id);


--
-- Name: agency_personnels agency_personnels_badge_number_key; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.agency_personnels
    ADD CONSTRAINT agency_personnels_badge_number_key UNIQUE (badge_number);


--
-- Name: agency_personnels agency_personnels_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.agency_personnels
    ADD CONSTRAINT agency_personnels_pkey PRIMARY KEY (user_id);


--
-- Name: emergency_contacts emergency_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.emergency_contacts
    ADD CONSTRAINT emergency_contacts_pkey PRIMARY KEY (id);


--
-- Name: incident_responses incident_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.incident_responses
    ADD CONSTRAINT incident_responses_pkey PRIMARY KEY (id);


--
-- Name: incidents incidents_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_pkey PRIMARY KEY (id);


--
-- Name: m_badges m_badges_badge_name_key; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.m_badges
    ADD CONSTRAINT m_badges_badge_name_key UNIQUE (badge_name);


--
-- Name: m_badges m_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.m_badges
    ADD CONSTRAINT m_badges_pkey PRIMARY KEY (id);


--
-- Name: m_ranks m_ranks_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.m_ranks
    ADD CONSTRAINT m_ranks_pkey PRIMARY KEY (id);


--
-- Name: m_ranks m_ranks_rank_name_key; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.m_ranks
    ADD CONSTRAINT m_ranks_rank_name_key UNIQUE (rank_name);


--
-- Name: incident_responses unique_responder_per_incident; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.incident_responses
    ADD CONSTRAINT unique_responder_per_incident UNIQUE (incident_id, responder_id);


--
-- Name: user_medical_profiles user_medical_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.user_medical_profiles
    ADD CONSTRAINT user_medical_profiles_pkey PRIMARY KEY (user_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_nik_key; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_nik_key UNIQUE (nik);


--
-- Name: users users_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_number_key UNIQUE (phone_number);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: volunteer_badges_acquired volunteer_badges_acquired_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.volunteer_badges_acquired
    ADD CONSTRAINT volunteer_badges_acquired_pkey PRIMARY KEY (id);


--
-- Name: volunteer_certifications volunteer_certifications_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.volunteer_certifications
    ADD CONSTRAINT volunteer_certifications_pkey PRIMARY KEY (id);


--
-- Name: volunteer_reputation volunteer_reputation_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.volunteer_reputation
    ADD CONSTRAINT volunteer_reputation_pkey PRIMARY KEY (user_id);


--
-- Name: idx_emergency_contacts_user_id; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_emergency_contacts_user_id ON public.emergency_contacts USING btree (user_id);


--
-- Name: idx_incident_responses_incident_id; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_incident_responses_incident_id ON public.incident_responses USING btree (incident_id);


--
-- Name: idx_incident_responses_responder_id; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_incident_responses_responder_id ON public.incident_responses USING btree (responder_id);


--
-- Name: idx_incidents_reporter_id; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_incidents_reporter_id ON public.incidents USING btree (reporter_id);


--
-- Name: idx_incidents_status; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_incidents_status ON public.incidents USING btree (status);


--
-- Name: idx_users_deleted_at; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_users_deleted_at ON public.users USING btree (deleted_at);


--
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- Name: idx_users_role; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_users_role ON public.users USING btree (role);


--
-- Name: user_medical_profiles trg_medical_updated_at; Type: TRIGGER; Schema: public; Owner: siagakita_admin
--

CREATE TRIGGER trg_medical_updated_at BEFORE UPDATE ON public.user_medical_profiles FOR EACH ROW EXECUTE FUNCTION public.update_medical_timestamp();


--
-- Name: volunteer_certifications trg_update_volunteer_status; Type: TRIGGER; Schema: public; Owner: siagakita_admin
--

CREATE TRIGGER trg_update_volunteer_status AFTER UPDATE ON public.volunteer_certifications FOR EACH ROW EXECUTE FUNCTION public.update_volunteer_verification_status();


--
-- Name: agency_personnels agency_personnels_agency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.agency_personnels
    ADD CONSTRAINT agency_personnels_agency_id_fkey FOREIGN KEY (agency_id) REFERENCES public.agencies(id) ON DELETE RESTRICT;


--
-- Name: agency_personnels agency_personnels_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.agency_personnels
    ADD CONSTRAINT agency_personnels_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: emergency_contacts emergency_contacts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.emergency_contacts
    ADD CONSTRAINT emergency_contacts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: incident_responses incident_responses_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.incident_responses
    ADD CONSTRAINT incident_responses_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id) ON DELETE CASCADE;


--
-- Name: incident_responses incident_responses_responder_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.incident_responses
    ADD CONSTRAINT incident_responses_responder_id_fkey FOREIGN KEY (responder_id) REFERENCES public.users(id);


--
-- Name: incidents incidents_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.users(id);


--
-- Name: user_medical_profiles user_medical_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.user_medical_profiles
    ADD CONSTRAINT user_medical_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: volunteer_badges_acquired volunteer_badges_acquired_badge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.volunteer_badges_acquired
    ADD CONSTRAINT volunteer_badges_acquired_badge_id_fkey FOREIGN KEY (badge_id) REFERENCES public.m_badges(id);


--
-- Name: volunteer_badges_acquired volunteer_badges_acquired_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.volunteer_badges_acquired
    ADD CONSTRAINT volunteer_badges_acquired_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: volunteer_certifications volunteer_certifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.volunteer_certifications
    ADD CONSTRAINT volunteer_certifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: volunteer_certifications volunteer_certifications_verified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.volunteer_certifications
    ADD CONSTRAINT volunteer_certifications_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES public.users(id);


--
-- Name: volunteer_reputation volunteer_reputation_rank_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.volunteer_reputation
    ADD CONSTRAINT volunteer_reputation_rank_id_fkey FOREIGN KEY (rank_id) REFERENCES public.m_ranks(id);


--
-- Name: volunteer_reputation volunteer_reputation_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.volunteer_reputation
    ADD CONSTRAINT volunteer_reputation_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

\unrestrict 6BqU5N7nDABDmHLYx2L0t7PNtJ5dryMvw0YlL4JsiHoPXHEs9ER01z3zNSWzRQ0


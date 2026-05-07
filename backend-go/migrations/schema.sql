--
-- PostgreSQL database dump
--

\restrict 5dsyoRNjdIs8TUJ79zkq2PiiCHm79jmiWpjMFRKLHnj6xXE2qbWG1WKHNkRvxNh

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
    'UNKNOWN',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
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
    'general',
    'unknown',
    'disaster'
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
    'false_alarm',
    'cancel'
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
    'superadmin',
    'admin',
    'agency',
    'agency_personnel',
    'volunteer',
    'civilian'
);


ALTER TYPE public.user_role OWNER TO siagakita_admin;

--
-- Name: fn_sync_volunteer_verified(); Type: FUNCTION; Schema: public; Owner: siagakita_admin
--

CREATE FUNCTION public.fn_sync_volunteer_verified() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.status = 'approved' THEN
        UPDATE public.user_profiles
           SET is_verified_volunteer = TRUE
         WHERE user_id = NEW.user_id;
    ELSIF OLD.status = 'approved' AND NEW.status != 'approved' THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.volunteer_certifications
             WHERE user_id = NEW.user_id
               AND status = 'approved'
               AND id != NEW.id
        ) THEN
            UPDATE public.user_profiles
               SET is_verified_volunteer = FALSE
             WHERE user_id = NEW.user_id;
        END IF;
    END IF;
    RETURN NEW;
END; $$;


ALTER FUNCTION public.fn_sync_volunteer_verified() OWNER TO siagakita_admin;

--
-- Name: fn_update_profile_ts(); Type: FUNCTION; Schema: public; Owner: siagakita_admin
--

CREATE FUNCTION public.fn_update_profile_ts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;


ALTER FUNCTION public.fn_update_profile_ts() OWNER TO siagakita_admin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_profiles; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.admin_profiles (
    user_id uuid NOT NULL,
    full_name character varying(100),
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.admin_profiles OWNER TO siagakita_admin;

--
-- Name: agencies; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.agencies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(100) NOT NULL,
    type public.agency_type NOT NULL,
    city_code character varying(50) NOT NULL,
    hotline_number character varying(20),
    account_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    latitude numeric(10,8),
    longitude numeric(11,8)
);


ALTER TABLE public.agencies OWNER TO siagakita_admin;

--
-- Name: agency_personnels; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.agency_personnels (
    user_id uuid NOT NULL,
    agency_id uuid NOT NULL,
    full_name character varying(100) NOT NULL,
    badge_number character varying(50) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.agency_personnels OWNER TO siagakita_admin;

--
-- Name: emergency_contacts; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.emergency_contacts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    contact_name character varying(100) NOT NULL,
    contact_phone character varying(20) NOT NULL,
    relation character varying(50),
    created_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone
);


ALTER TABLE public.emergency_contacts OWNER TO siagakita_admin;

--
-- Name: incident_reports; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.incident_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reporter_id uuid NOT NULL,
    incident_type character varying(50) NOT NULL,
    urgency_level smallint DEFAULT 1 NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    description text,
    photo_paths text[] DEFAULT '{}'::text[],
    audio_path text,
    status character varying(20) DEFAULT 'received'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.incident_reports OWNER TO siagakita_admin;

--
-- Name: incident_responses; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.incident_responses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
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
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reporter_id uuid,
    incident_type public.incident_category DEFAULT 'unknown'::public.incident_category NOT NULL,
    latitude numeric(10,8) NOT NULL,
    longitude numeric(11,8) NOT NULL,
    status public.incident_status DEFAULT 'grace_period'::public.incident_status,
    urgency_level character varying(10) DEFAULT 'unknown'::character varying,
    reporter_trust_label character varying(20) DEFAULT 'standard'::character varying,
    address_detail text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    resolved_at timestamp with time zone,
    photo_paths text[] DEFAULT '{}'::text[],
    audio_path text
);


ALTER TABLE public.incidents OWNER TO siagakita_admin;

--
-- Name: m_badges; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.m_badges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
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
-- Name: sos_strikes; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.sos_strikes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    incident_id uuid,
    reason text,
    marked_by uuid,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.sos_strikes OWNER TO siagakita_admin;

--
-- Name: user_profiles; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.user_profiles (
    user_id uuid NOT NULL,
    full_name character varying(100),
    nik character varying(16),
    date_of_birth date,
    phone_number character varying(20),
    is_email_verified boolean DEFAULT false,
    is_phone_verified boolean DEFAULT false,
    is_verified_volunteer boolean DEFAULT false,
    sos_strike_count integer DEFAULT 0,
    is_sos_banned boolean DEFAULT false,
    banned_until timestamp with time zone,
    blood_type public.blood_type_enum DEFAULT 'UNKNOWN'::public.blood_type_enum,
    allergies text,
    medical_conditions text,
    height_cm integer,
    weight_kg integer,
    alamat text,
    updated_at timestamp with time zone DEFAULT now(),
    bio text,
    CONSTRAINT user_profiles_height_cm_check CHECK ((height_cm > 0)),
    CONSTRAINT user_profiles_weight_kg_check CHECK ((weight_kg > 0))
);


ALTER TABLE public.user_profiles OWNER TO siagakita_admin;

--
-- Name: users; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying(100) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role public.user_role DEFAULT 'civilian'::public.user_role NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.users OWNER TO siagakita_admin;

--
-- Name: volunteer_badges_acquired; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.volunteer_badges_acquired (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    badge_id uuid,
    earned_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.volunteer_badges_acquired OWNER TO siagakita_admin;

--
-- Name: volunteer_certifications; Type: TABLE; Schema: public; Owner: siagakita_admin
--

CREATE TABLE public.volunteer_certifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
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
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.volunteer_reputation OWNER TO siagakita_admin;

--
-- Name: m_ranks id; Type: DEFAULT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.m_ranks ALTER COLUMN id SET DEFAULT nextval('public.m_ranks_id_seq'::regclass);


--
-- Name: admin_profiles admin_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.admin_profiles
    ADD CONSTRAINT admin_profiles_pkey PRIMARY KEY (user_id);


--
-- Name: agencies agencies_account_id_key; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.agencies
    ADD CONSTRAINT agencies_account_id_key UNIQUE (account_id);


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
-- Name: incident_reports incident_reports_v2_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.incident_reports
    ADD CONSTRAINT incident_reports_v2_pkey PRIMARY KEY (id);


--
-- Name: incident_responses incident_responses_incident_id_responder_id_key; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.incident_responses
    ADD CONSTRAINT incident_responses_incident_id_responder_id_key UNIQUE (incident_id, responder_id);


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
-- Name: sos_strikes sos_strikes_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.sos_strikes
    ADD CONSTRAINT sos_strikes_pkey PRIMARY KEY (id);


--
-- Name: user_profiles user_profiles_nik_key; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_nik_key UNIQUE (nik);


--
-- Name: user_profiles user_profiles_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_phone_number_key UNIQUE (phone_number);


--
-- Name: user_profiles user_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (user_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


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
-- Name: idx_ap_agency; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_ap_agency ON public.agency_personnels USING btree (agency_id);


--
-- Name: idx_ec_user; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_ec_user ON public.emergency_contacts USING btree (user_id);


--
-- Name: idx_incident_reports_created_at; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_incident_reports_created_at ON public.incident_reports USING btree (created_at DESC);


--
-- Name: idx_incident_reports_reporter_id; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_incident_reports_reporter_id ON public.incident_reports USING btree (reporter_id);


--
-- Name: idx_incident_reports_status; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_incident_reports_status ON public.incident_reports USING btree (status);


--
-- Name: idx_incidents_reporter; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_incidents_reporter ON public.incidents USING btree (reporter_id);


--
-- Name: idx_incidents_status; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_incidents_status ON public.incidents USING btree (status);


--
-- Name: idx_ir_incident; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_ir_incident ON public.incident_responses USING btree (incident_id);


--
-- Name: idx_ir_responder; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_ir_responder ON public.incident_responses USING btree (responder_id);


--
-- Name: idx_up_nik; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_up_nik ON public.user_profiles USING btree (nik);


--
-- Name: idx_up_phone; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_up_phone ON public.user_profiles USING btree (phone_number);


--
-- Name: idx_users_del; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_users_del ON public.users USING btree (deleted_at);


--
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- Name: idx_users_role; Type: INDEX; Schema: public; Owner: siagakita_admin
--

CREATE INDEX idx_users_role ON public.users USING btree (role);


--
-- Name: admin_profiles trg_admin_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: siagakita_admin
--

CREATE TRIGGER trg_admin_profiles_updated_at BEFORE UPDATE ON public.admin_profiles FOR EACH ROW EXECUTE FUNCTION public.fn_update_profile_ts();


--
-- Name: volunteer_certifications trg_sync_volunteer_verified; Type: TRIGGER; Schema: public; Owner: siagakita_admin
--

CREATE TRIGGER trg_sync_volunteer_verified AFTER UPDATE ON public.volunteer_certifications FOR EACH ROW EXECUTE FUNCTION public.fn_sync_volunteer_verified();


--
-- Name: user_profiles trg_user_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: siagakita_admin
--

CREATE TRIGGER trg_user_profiles_updated_at BEFORE UPDATE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.fn_update_profile_ts();


--
-- Name: admin_profiles admin_profiles_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.admin_profiles
    ADD CONSTRAINT admin_profiles_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: admin_profiles admin_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.admin_profiles
    ADD CONSTRAINT admin_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: agencies agencies_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.agencies
    ADD CONSTRAINT agencies_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.users(id);


--
-- Name: agency_personnels agency_personnels_agency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.agency_personnels
    ADD CONSTRAINT agency_personnels_agency_id_fkey FOREIGN KEY (agency_id) REFERENCES public.agencies(id) ON DELETE RESTRICT;


--
-- Name: agency_personnels agency_personnels_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.agency_personnels
    ADD CONSTRAINT agency_personnels_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: emergency_contacts emergency_contacts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.emergency_contacts
    ADD CONSTRAINT emergency_contacts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: incident_reports incident_reports_v2_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.incident_reports
    ADD CONSTRAINT incident_reports_v2_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.users(id) ON DELETE CASCADE;


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
-- Name: sos_strikes sos_strikes_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.sos_strikes
    ADD CONSTRAINT sos_strikes_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id) ON DELETE SET NULL;


--
-- Name: sos_strikes sos_strikes_marked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.sos_strikes
    ADD CONSTRAINT sos_strikes_marked_by_fkey FOREIGN KEY (marked_by) REFERENCES public.users(id);


--
-- Name: sos_strikes sos_strikes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.sos_strikes
    ADD CONSTRAINT sos_strikes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_profiles user_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: volunteer_badges_acquired volunteer_badges_acquired_badge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.volunteer_badges_acquired
    ADD CONSTRAINT volunteer_badges_acquired_badge_id_fkey FOREIGN KEY (badge_id) REFERENCES public.m_badges(id);


--
-- Name: volunteer_badges_acquired volunteer_badges_acquired_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.volunteer_badges_acquired
    ADD CONSTRAINT volunteer_badges_acquired_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: volunteer_certifications volunteer_certifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: siagakita_admin
--

ALTER TABLE ONLY public.volunteer_certifications
    ADD CONSTRAINT volunteer_certifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


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
    ADD CONSTRAINT volunteer_reputation_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict 5dsyoRNjdIs8TUJ79zkq2PiiCHm79jmiWpjMFRKLHnj6xXE2qbWG1WKHNkRvxNh


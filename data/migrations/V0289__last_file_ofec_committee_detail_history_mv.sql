/*
This migration file is for #5712

1) Add `last_file_date` and `last_f1_date`index to ofec_committee_history_mv and ofec_committee_history_vw

Replaces V0250

2) Add ``last_f1_date` index to ofec_committee_detail_mv and ofec_committee_detail_vw

Replaces V0238

*/

DROP MATERIALIZED VIEW IF EXISTS public.ofec_committee_history_mv_tmp;

CREATE MATERIALIZED VIEW public.ofec_committee_history_mv_tmp AS
WITH cycles AS
(
    SELECT cmte_valid_fec_yr.cmte_id,
    array_agg(cmte_valid_fec_yr.fec_election_yr) FILTER (WHERE cmte_valid_fec_yr.fec_election_yr is not NULL)::integer[] AS cycles,
    max(cmte_valid_fec_yr.fec_election_yr) AS max_cycle
    FROM disclosure.cmte_valid_fec_yr
    GROUP BY cmte_valid_fec_yr.cmte_id
), dates AS
(
    SELECT f_rpt_or_form_sub.cand_cmte_id AS cmte_id,
    min(f_rpt_or_form_sub.receipt_dt) AS first_file_date,
    max(f_rpt_or_form_sub.receipt_dt) AS last_file_date,
    max(f_rpt_or_form_sub.receipt_dt) FILTER (WHERE f_rpt_or_form_sub.form_tp::text = 'F1'::text) AS last_f1_date,
    min(f_rpt_or_form_sub.receipt_dt) FILTER (WHERE f_rpt_or_form_sub.form_tp::text = 'F1'::text) AS first_f1_date,
    max(get_cycle(f_rpt_or_form_sub.rpt_yr)) AS last_cycle_has_activity,
    array_agg(DISTINCT get_cycle(f_rpt_or_form_sub.rpt_yr)) FILTER (WHERE f_rpt_or_form_sub.rpt_yr is not NULL) AS cycles_has_activity
    FROM disclosure.f_rpt_or_form_sub
    GROUP BY f_rpt_or_form_sub.cand_cmte_id
), candidates AS
(
    SELECT cand_cmte_linkage.cmte_id,
    array_agg(DISTINCT cand_cmte_linkage.cand_id)::text[] AS candidate_ids
    FROM disclosure.cand_cmte_linkage
    GROUP BY cand_cmte_linkage.cmte_id
), reports AS
(
    SELECT f_rpt_or_form_sub.cand_cmte_id AS cmte_id,
    max(get_cycle(f_rpt_or_form_sub.rpt_yr)) AS last_cycle_has_financial,
    array_agg(DISTINCT get_cycle(f_rpt_or_form_sub.rpt_yr)) FILTER (WHERE f_rpt_or_form_sub.rpt_yr is not NULL) AS cycles_has_financial
    FROM disclosure.f_rpt_or_form_sub
    WHERE upper(f_rpt_or_form_sub.form_tp::text) = ANY (ARRAY['F3'::text, 'F3X'::text, 'F3P'::text, 'F3L'::text, 'F4'::text, 'F5'::text, 'F7'::text, 'F13'::text, 'F24'::text, 'F6'::text, 'F9'::text, 'F10'::text, 'F11'::text])
    GROUP BY f_rpt_or_form_sub.cand_cmte_id
), leadership_pac_linkage AS
(
    SELECT cand_cmte_linkage_alternate.cmte_id, cand_cmte_linkage_alternate.fec_election_yr,
    array_agg(DISTINCT cand_cmte_linkage_alternate.cand_id)::text[] AS sponsor_candidate_ids
    FROM disclosure.cand_cmte_linkage_alternate
    WHERE linkage_type = 'D'
    GROUP BY cand_cmte_linkage_alternate.cmte_id, cand_cmte_linkage_alternate.fec_election_yr
)
SELECT DISTINCT ON (fec_yr.cmte_id, fec_yr.fec_election_yr) row_number() OVER () AS idx,
    fec_yr.fec_election_yr AS cycle,
    fec_yr.cmte_id AS committee_id,
    fec_yr.cmte_nm AS name,
    fec_yr.tres_nm AS treasurer_name,
    to_tsvector(parse_fulltext(fec_yr.tres_nm::text)::text) AS treasurer_text,
    f1.org_tp AS organization_type,
    expand_organization_type(f1.org_tp::text) AS organization_type_full,
    fec_yr.cmte_st1 AS street_1,
    fec_yr.cmte_st2 AS street_2,
    fec_yr.cmte_city AS city,
    fec_yr.cmte_st AS state,
    expand_state(fec_yr.cmte_st::text) AS state_full,
    fec_yr.cmte_zip AS zip,
    f1.tres_city AS treasurer_city,
    f1.tres_f_nm AS treasurer_name_1,
    f1.tres_l_nm AS treasurer_name_2,
    f1.tres_m_nm AS treasurer_name_middle,
    f1.tres_ph_num AS treasurer_phone,
    f1.tres_prefix AS treasurer_name_prefix,
    f1.tres_st AS treasurer_state,
    f1.tres_st1 AS treasurer_street_1,
    f1.tres_st2 AS treasurer_street_2,
    f1.tres_suffix AS treasurer_name_suffix,
    f1.tres_title AS treasurer_name_title,
    f1.tres_zip AS treasurer_zip,
    f1.cust_rec_city AS custodian_city,
    f1.cust_rec_f_nm AS custodian_name_1,
    f1.cust_rec_l_nm AS custodian_name_2,
    f1.cust_rec_m_nm AS custodian_name_middle,
    f1.cust_rec_nm AS custodian_name_full,
    f1.cust_rec_ph_num AS custodian_phone,
    f1.cust_rec_prefix AS custodian_name_prefix,
    f1.cust_rec_st AS custodian_state,
    f1.cust_rec_st1 AS custodian_street_1,
    f1.cust_rec_st2 AS custodian_street_2,
    f1.cust_rec_suffix AS custodian_name_suffix,
    f1.cust_rec_title AS custodian_name_title,
    f1.cust_rec_zip AS custodian_zip,
    fec_yr.cmte_email AS email,
    f1.cmte_fax AS fax,
    fec_yr.cmte_url AS website,
    f1.form_tp AS form_type,
    f1.leadership_pac,
    f1.lobbyist_registrant_pac,
    f1.cand_pty_tp AS party_type,
    f1.cand_pty_tp_desc AS party_type_full,
    f1.qual_dt AS qualifying_date,
    dates.first_file_date::text::date AS first_file_date,
    dates.last_file_date::text::date AS last_file_date,
    dates.last_f1_date::text::date AS last_f1_date,
    fec_yr.cmte_dsgn AS designation,
    expand_committee_designation(fec_yr.cmte_dsgn::text) AS designation_full,
    fec_yr.cmte_tp AS committee_type,
    expand_committee_type(fec_yr.cmte_tp::text) AS committee_type_full,
    fec_yr.cmte_filing_freq AS filing_frequency,
    fec_yr.cmte_pty_affiliation AS party,
    fec_yr.cmte_pty_affiliation_desc AS party_full,
    cycles.cycles,
    COALESCE(candidates.candidate_ids, '{}'::text[]) AS candidate_ids,
    f1.affiliated_cmte_nm AS affiliated_committee_name,
    reports.last_cycle_has_financial,
    reports.cycles_has_financial,
    dates.last_cycle_has_activity,
    dates.cycles_has_activity,
    is_committee_active(fec_yr.cmte_filing_freq) AS is_active,
    l.sponsor_candidate_ids,
    (case when pcc.cand_id is null then false else true end)::bool as convert_to_pac_flag,
    pcc.first_cmte_nm as former_committee_name,
    pcc.cand_id as former_candidate_id,
    pcc.cand_name as former_candidate_name,
    pcc.candidate_election_year as former_candidate_election_year,
    dates.first_f1_date::text::date AS first_f1_date,
    get_committee_label(fec_yr.cmte_tp, fec_yr.cmte_dsgn,f1.org_tp) as committee_label
FROM disclosure.cmte_valid_fec_yr fec_yr
LEFT JOIN fec_vsum_f1_vw f1 ON fec_yr.cmte_id::text = f1.cmte_id::text AND fec_yr.fec_election_yr >= f1.rpt_yr
LEFT JOIN cycles ON fec_yr.cmte_id::text = cycles.cmte_id::text
LEFT JOIN dates ON fec_yr.cmte_id::text = dates.cmte_id::text
LEFT JOIN candidates ON fec_yr.cmte_id::text = candidates.cmte_id::text
LEFT JOIN reports ON fec_yr.cmte_id::text = reports.cmte_id::text
LEFT JOIN leadership_pac_linkage l ON fec_yr.cmte_id::text = l.cmte_id::text AND fec_yr.fec_election_yr = l.fec_election_yr
LEFT JOIN ofec_pcc_to_pac_vw pcc on pcc.cmte_id = fec_yr.cmte_id and pcc.fec_election_yr = fec_yr.fec_election_yr
WHERE cycles.max_cycle >= 1979::numeric AND NOT (fec_yr.cmte_id::text IN ( SELECT DISTINCT unverified_filers_vw.cmte_id
        FROM unverified_filers_vw
        WHERE unverified_filers_vw.cmte_id::text ~~ 'C%'::text))
ORDER BY fec_yr.cmte_id, fec_yr.fec_election_yr DESC, f1.rpt_yr DESC
WITH DATA;

--Permissions

ALTER TABLE public.ofec_committee_history_mv_tmp OWNER TO fec;
GRANT ALL ON TABLE public.ofec_committee_history_mv_tmp TO fec;
GRANT SELECT ON TABLE public.ofec_committee_history_mv_tmp TO fec_read;

--Indices

CREATE UNIQUE INDEX idx_ofec_committee_history_mv_tmp_idx
 ON public.ofec_committee_history_mv_tmp
 USING btree
 (idx);
CREATE INDEX idx_ofec_committee_history_mv_tmp_committee_id
 ON public.ofec_committee_history_mv_tmp
 USING btree
 (committee_id);
CREATE INDEX idx_ofec_committee_history_mv_tmp_cycle_committee_id
 ON public.ofec_committee_history_mv_tmp
 USING btree
 (cycle, committee_id);
CREATE INDEX idx_ofec_committee_history_mv_tmp_cycle
 ON public.ofec_committee_history_mv_tmp
 USING btree
 (cycle);
CREATE INDEX idx_ofec_committee_history_mv_tmp_designation
 ON public.ofec_committee_history_mv_tmp
 USING btree
 (designation);
CREATE INDEX idx_ofec_committee_history_mv_tmp_first_file_date
 ON public.ofec_committee_history_mv_tmp
 USING btree
 (first_file_date);
CREATE INDEX idx_ofec_committee_history_mv_tmp_name
 ON public.ofec_committee_history_mv_tmp
 USING btree
 (name);
CREATE INDEX idx_ofec_committee_history_mv_tmp_state
 ON public.ofec_committee_history_mv_tmp
 USING btree
 (state);
CREATE INDEX idx_ofec_committee_history_mv_tmp_comid_state
 ON public.ofec_committee_history_mv_tmp
 USING btree
 (committee_id, state);
CREATE INDEX idx_ofec_committee_history_mv_tmp_first_f1_date
 ON public.ofec_committee_history_mv_tmp
 USING btree
 (first_f1_date);
 CREATE INDEX idx_ofec_committee_history_mv_tmp_last_f1_date
 ON public.ofec_committee_history_mv_tmp
 USING btree
 (last_f1_date);
 CREATE INDEX idx_ofec_committee_history_mv_tmp_last_file_date
 ON public.ofec_committee_history_mv_tmp
 USING btree
 (last_file_date);


-- ---------
CREATE OR REPLACE VIEW public.ofec_committee_history_vw AS
SELECT * FROM public.ofec_committee_history_mv_tmp;

ALTER TABLE public.ofec_committee_history_vw OWNER TO fec;
GRANT ALL ON TABLE public.ofec_committee_history_vw TO fec;
GRANT SELECT ON TABLE public.ofec_committee_history_vw TO fec_read;

-- ----------
DROP MATERIALIZED VIEW IF EXISTS public.ofec_committee_history_mv;
ALTER MATERIALIZED VIEW IF EXISTS public.ofec_committee_history_mv_tmp RENAME TO ofec_committee_history_mv;
-- ----------
ALTER INDEX public.idx_ofec_committee_history_mv_tmp_idx RENAME TO idx_ofec_committee_history_mv_idx;
ALTER INDEX public.idx_ofec_committee_history_mv_tmp_committee_id RENAME TO idx_ofec_committee_history_mv_committee_id;
ALTER INDEX public.idx_ofec_committee_history_mv_tmp_cycle_committee_id RENAME TO idx_ofec_committee_history_mv_cycle_committee_id;
ALTER INDEX public.idx_ofec_committee_history_mv_tmp_cycle RENAME TO idx_ofec_committee_history_mv_cycle;
ALTER INDEX public.idx_ofec_committee_history_mv_tmp_designation RENAME TO idx_ofec_committee_history_mv_designation;
ALTER INDEX public.idx_ofec_committee_history_mv_tmp_first_file_date RENAME TO idx_ofec_committee_history_mv_first_file_date;
ALTER INDEX public.idx_ofec_committee_history_mv_tmp_name RENAME TO idx_ofec_committee_history_mv_name;
ALTER INDEX public.idx_ofec_committee_history_mv_tmp_state RENAME TO idx_ofec_committee_history_mv_state;
ALTER INDEX public.idx_ofec_committee_history_mv_tmp_comid_state RENAME TO idx_ofec_committee_history_mv_comid_state;
ALTER INDEX public.idx_ofec_committee_history_mv_tmp_first_f1_date RENAME TO idx_ofec_committee_history_mv_first_f1_date;
ALTER INDEX public.idx_ofec_committee_history_mv_tmp_last_f1_date RENAME TO idx_ofec_committee_history_mv_last_f1_date;
ALTER INDEX public.idx_ofec_committee_history_mv_tmp_last_file_date RENAME TO idx_ofec_committee_history_mv_last_file_date;

-- 2) Add ``last_f1_date` index to ofec_committee_detail_mv and ofec_committee_detail_vw

-- ----------
-- ofec_committee_detail_mv
-- ----------
DROP MATERIALIZED VIEW IF EXISTS public.ofec_committee_detail_mv_tmp;

CREATE MATERIALIZED VIEW public.ofec_committee_detail_mv_tmp AS
SELECT DISTINCT ON (ofec_committee_history_vw.committee_id) ofec_committee_history_vw.idx,
    ofec_committee_history_vw.cycle,
    ofec_committee_history_vw.committee_id,
    ofec_committee_history_vw.name,
    ofec_committee_history_vw.treasurer_name,
    ofec_committee_history_vw.treasurer_text,
    ofec_committee_history_vw.organization_type,
    ofec_committee_history_vw.organization_type_full,
    ofec_committee_history_vw.street_1,
    ofec_committee_history_vw.street_2,
    ofec_committee_history_vw.city,
    ofec_committee_history_vw.state,
    ofec_committee_history_vw.state_full,
    ofec_committee_history_vw.zip,
    ofec_committee_history_vw.treasurer_city,
    ofec_committee_history_vw.treasurer_name_1,
    ofec_committee_history_vw.treasurer_name_2,
    ofec_committee_history_vw.treasurer_name_middle,
    ofec_committee_history_vw.treasurer_phone,
    ofec_committee_history_vw.treasurer_name_prefix,
    ofec_committee_history_vw.treasurer_state,
    ofec_committee_history_vw.treasurer_street_1,
    ofec_committee_history_vw.treasurer_street_2,
    ofec_committee_history_vw.treasurer_name_suffix,
    ofec_committee_history_vw.treasurer_name_title,
    ofec_committee_history_vw.treasurer_zip,
    ofec_committee_history_vw.custodian_city,
    ofec_committee_history_vw.custodian_name_1,
    ofec_committee_history_vw.custodian_name_2,
    ofec_committee_history_vw.custodian_name_middle,
    ofec_committee_history_vw.custodian_name_full,
    ofec_committee_history_vw.custodian_phone,
    ofec_committee_history_vw.custodian_name_prefix,
    ofec_committee_history_vw.custodian_state,
    ofec_committee_history_vw.custodian_street_1,
    ofec_committee_history_vw.custodian_street_2,
    ofec_committee_history_vw.custodian_name_suffix,
    ofec_committee_history_vw.custodian_name_title,
    ofec_committee_history_vw.custodian_zip,
    ofec_committee_history_vw.email,
    ofec_committee_history_vw.fax,
    ofec_committee_history_vw.website,
    ofec_committee_history_vw.form_type,
    ofec_committee_history_vw.leadership_pac,
    ofec_committee_history_vw.lobbyist_registrant_pac,
    ofec_committee_history_vw.party_type,
    ofec_committee_history_vw.party_type_full,
    ofec_committee_history_vw.qualifying_date,
    ofec_committee_history_vw.first_file_date,
    ofec_committee_history_vw.last_file_date,
    ofec_committee_history_vw.last_f1_date,
    ofec_committee_history_vw.designation,
    ofec_committee_history_vw.designation_full,
    ofec_committee_history_vw.committee_type,
    ofec_committee_history_vw.committee_type_full,
    ofec_committee_history_vw.filing_frequency,
    ofec_committee_history_vw.party,
    ofec_committee_history_vw.party_full,
    ofec_committee_history_vw.cycles,
    ofec_committee_history_vw.candidate_ids,
    ofec_committee_history_vw.affiliated_committee_name,
    ofec_committee_history_vw.is_active,
    ofec_committee_history_vw.sponsor_candidate_ids,
    ofec_committee_history_vw.first_f1_date
   FROM ofec_committee_history_vw
  ORDER BY ofec_committee_history_vw.committee_id, ofec_committee_history_vw.cycle DESC
WITH DATA;

--Permissions

ALTER TABLE public.ofec_committee_detail_mv_tmp OWNER TO fec;
GRANT ALL ON TABLE public.ofec_committee_detail_mv_tmp TO fec;
GRANT SELECT ON TABLE public.ofec_committee_detail_mv_tmp TO fec_read;

--Indices

CREATE INDEX idx_ofec_committee_detail_mv_tmp_candidate_ids
    ON public.ofec_committee_detail_mv_tmp USING gin
    (candidate_ids);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_committee_id
    ON public.ofec_committee_detail_mv_tmp USING btree
    (committee_id);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_committee_type
    ON public.ofec_committee_detail_mv_tmp USING btree
    (committee_type);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_committee_type_full
    ON public.ofec_committee_detail_mv_tmp USING btree
    (committee_type_full);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_cycles
    ON public.ofec_committee_detail_mv_tmp USING gin
    (cycles);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_cycles_candidate_ids
    ON public.ofec_committee_detail_mv_tmp USING gin
    (cycles, candidate_ids);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_designation
    ON public.ofec_committee_detail_mv_tmp USING btree
    (designation);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_designation_full
    ON public.ofec_committee_detail_mv_tmp USING btree
    (designation_full);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_first_file_date
    ON public.ofec_committee_detail_mv_tmp USING btree
    (first_file_date);
CREATE UNIQUE INDEX idx_ofec_committee_detail_mv_tmp_idx
    ON public.ofec_committee_detail_mv_tmp USING btree
    (idx);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_last_file_date
    ON public.ofec_committee_detail_mv_tmp USING btree
    (last_file_date);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_name
    ON public.ofec_committee_detail_mv_tmp USING btree
    (name);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_organization_type
    ON public.ofec_committee_detail_mv_tmp USING btree
    (organization_type);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_organization_type_full
    ON public.ofec_committee_detail_mv_tmp USING btree
    (organization_type_full);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_party
    ON public.ofec_committee_detail_mv_tmp USING btree
    (party);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_party_full
    ON public.ofec_committee_detail_mv_tmp USING btree
    (party_full);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_state
    ON public.ofec_committee_detail_mv_tmp USING btree
    (state);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_treasurer_name
    ON public.ofec_committee_detail_mv_tmp USING btree
    (treasurer_name);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_treasurer_text
    ON public.ofec_committee_detail_mv_tmp USING gin
    (treasurer_text);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_first_f1_date
    ON public.ofec_committee_detail_mv_tmp USING btree
    (first_f1_date);
CREATE INDEX idx_ofec_committee_detail_mv_tmp_last_f1_date
    ON public.ofec_committee_detail_mv_tmp USING btree
    (last_f1_date);


-- ---------
CREATE OR REPLACE VIEW public.ofec_committee_detail_vw AS
SELECT * FROM public.ofec_committee_detail_mv_tmp;

ALTER TABLE public.ofec_committee_detail_vw OWNER TO fec;
GRANT ALL ON TABLE public.ofec_committee_detail_vw TO fec;
GRANT SELECT ON TABLE public.ofec_committee_detail_vw TO fec_read;

--rename
DROP MATERIALIZED VIEW IF EXISTS public.ofec_committee_detail_mv;
ALTER MATERIALIZED VIEW IF EXISTS public.ofec_committee_detail_mv_tmp RENAME TO ofec_committee_detail_mv;
-- ----------
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_idx RENAME TO idx_ofec_committee_detail_mv_idx;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_candidate_ids RENAME TO idx_ofec_committee_detail_mv_candidate_ids;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_committee_id RENAME TO idx_ofec_committee_detail_mv_committee_id;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_committee_type_full RENAME TO idx_ofec_committee_detail_mv_committee_type_full;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_committee_type RENAME TO idx_ofec_committee_detail_mv_committee_type;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_cycles_candidate_ids RENAME TO idx_ofec_committee_detail_mv_cycles_candidate_ids;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_cycles RENAME TO idx_ofec_committee_detail_mv_cycles;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_designation_full RENAME TO idx_ofec_committee_detail_mv_designation_full;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_designation RENAME TO idx_ofec_committee_detail_mv_designation;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_first_file_date RENAME TO idx_ofec_committee_detail_mv_first_file_date;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_last_file_date RENAME TO idx_ofec_committee_detail_mv_last_file_date;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_name RENAME TO idx_ofec_committee_detail_mv_name;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_organization_type_full RENAME TO idx_ofec_committee_detail_mv_organization_type_full;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_organization_type RENAME TO idx_ofec_committee_detail_mv_organization_type;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_party_full RENAME TO idx_ofec_committee_detail_mv_party_full;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_party RENAME TO idx_ofec_committee_detail_mv_party;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_state RENAME TO idx_ofec_committee_detail_mv_state;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_treasurer_name RENAME TO idx_ofec_committee_detail_mv_treasurer_name;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_treasurer_text RENAME TO idx_ofec_committee_detail_mv_treasurer_text;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_first_f1_date RENAME TO idx_ofec_committee_detail_mv_first_f1_date;
ALTER INDEX public.idx_ofec_committee_detail_mv_tmp_last_f1_date RENAME TO idx_ofec_committee_detail_mv_last_f1_date;


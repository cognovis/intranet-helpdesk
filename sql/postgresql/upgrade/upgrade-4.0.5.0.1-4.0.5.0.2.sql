-- 4.0.5.0.1-4.0.5.0.2.sql
SELECT acs_log__debug('/packages/intranet-helpdesk/sql/postgresql/upgrade/4.0.5.0.1-4.0.5.0.2.sql','');


-- A report that shows activities per day
--
SELECT im_report_new (
	'Helpdesk Tickets Closed Per Day',					-- report_name
	'helpdesk_ticket_closed_per_day',					-- report_code
	'intranet-helpdesk',							-- package_key
	150,									-- report_sort_order
	(select menu_id from im_menus where label = 'reporting-tickets'),	-- parent_menu_id
	'dummy - will be replaced below'    	    				-- SQL to execute
);

update im_reports 
set report_description = 'All tickets closed (initially) on a certain day.'
where report_code = 'helpdesk_ticket_closed_per_day';

SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'helpdesk_ticket_closed_per_day'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);


update im_reports 
set report_sql = '
	select	im_day_enumerator as date,
		''<a href=/intranet/projects/view?project_id=''|| p.parent_id || ''>'' || acs_object__name(p.parent_id) || ''</a>'' as sla,
		''<a href=/intranet-helpdesk/new?form_mode=display&ticket_id=''|| t.ticket_id || ''>'' || project_name || ''</a>'' as ticket,
		im_category_from_id(t.ticket_status_id) as status,
		im_category_from_id(t.ticket_type_id) as type,
		coalesce(t.ticket_note, '''') || '' '' || coalesce(t.ticket_description, '''') as description
	from	im_day_enumerator(now()::date - 30, now()::date +1)
		LEFT OUTER JOIN im_tickets t ON (im_day_enumerator::date = t.ticket_done_date::date)
		LEFT OUTER JOIN im_projects p ON (t.ticket_id = p.project_id)
	order by date, sla, ticket
'
where report_code = 'helpdesk_ticket_closed_per_day';



# /packages/intranet-helpdesk/www/index.tcl
#
# Copyright (c) 1998-2008 ]project-open[
# All rights reserved

# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    @author frank.bergmann@ticket-open.com
} {
    { order_by "Createion Date" }
    { mine_p "queue" }
    { ticket_status_id:integer "[im_ticket_status_open]" } 
    { ticket_type_id:integer 0 } 
    { ticket_queue_id:integer 0 } 
    { customer_id:integer 0 } 
    { customer_contact_id:integer 0 } 
    { assignee_id:integer 0 } 
    { letter:trim "" }
    { start_idx:integer 0 }
    { how_many "" }
    { view_name "ticket_list" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
set page_title [lang::message::lookup "" intranet-helpdesk.Tickets "Tickets"]
set context_bar [im_context_bar $page_title]
set page_focus "im_header_form.keywords"
set letter [string toupper $letter]

# Unprivileged users can only see their own tickets
#if {"all" == $mine_p && ![im_permission $current_user_id "view_tickets_all"]} {
#    set mine_p "queue"
#}

if { [empty_string_p $how_many] || $how_many < 1 } {
    set how_many [ad_parameter -package_id [im_package_core_id] NumberResultsPerPage  "" 50]
}
set end_idx [expr $start_idx + $how_many]

# ---------------------------------------------------------------
# Defined Table Fields
# ---------------------------------------------------------------

# Define the column headers and column contents that 
# we want to show:
#
set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name" -default 0]
if {!$view_id } {
    ad_return_complaint 1 "<b>Unknown View Name</b>:<br> The view '$view_name' is not defined.<br> 
    Maybe you need to upgrade the database. <br> Please notify your system administrator."
    return
}

set column_headers [list]
set column_vars [list]
set extra_selects [list]
set extra_froms [list]
set extra_wheres [list]
set view_order_by_clause ""

set column_sql "
	select	vc.*
	from	im_view_columns vc
	where	view_id=:view_id
		and group_id is null
	order by sort_order
"
db_foreach column_list_sql $column_sql {
    if {"" == $visible_for || [eval $visible_for]} {
	lappend column_headers "$column_name"
	lappend column_vars "$column_render_tcl"
	if {"" != $extra_select} { lappend extra_selects $extra_select }
	if {"" != $extra_from} { lappend extra_froms $extra_from }
	if {"" != $extra_where} { lappend extra_wheres $extra_where }
	if {"" != $order_by_clause &&
	    $order_by==$column_name} {
	    set view_order_by_clause $order_by_clause
	}
    }
}

# ---------------------------------------------------------------
# Filter with Dynamic Fields
# ---------------------------------------------------------------

set dynamic_fields_p 1
set form_id "ticket_filter"
set object_type "im_ticket"
set action_url "/intranet-helpdesk/index"
set form_mode "edit"
set mine_p_options [list \
	[list [lang::message::lookup "" intranet-helpdesk.All "All"] "all" ] \
	[list [lang::message::lookup "" intranet-helpdesk.My_queues "My Queues"] "queue"] \
	[list [lang::message::lookup "" intranet-helpdesk.Mine "Mine"] "mine"] \
]

set ticket_member_options [util_memoize "db_list_of_lists ticket_members {
        select  distinct
                im_name_from_user_id(object_id_two) as user_name,
                object_id_two as user_id
        from    acs_rels r,
                im_tickets p
        where   r.object_id_one = p.ticket_id
        order by user_name
}" 300]
set ticket_member_options [linsert $ticket_member_options 0 [list [_ intranet-core.All] ""]]

set ticket_queue_options [im_helpdesk_ticket_queue_options]

ad_form \
    -name $form_id \
    -action $action_url \
    -mode $form_mode \
    -method GET \
    -export {start_idx order_by how_many view_name letter } \
    -form {
    	{mine_p:text(select),optional {label "Mine/All"} {options $mine_p_options }}
    }

if {[im_permission $current_user_id "view_tickets_all"]} {  
    ad_form -extend -name $form_id -form {
	{ticket_status_id:text(im_category_tree),optional {label "[lang::message::lookup {} intranet-helpdesk.Status Status]"} {custom {category_type "Intranet Ticket Status" translate_p 1}} }
	{ticket_type_id:text(im_category_tree),optional {label "[lang::message::lookup {} intranet-helpdesk.Type Type]"} {custom {category_type "Intranet Ticket Type" translate_p 1} } }
	{ticket_queue_id:text(select),optional {label "[lang::message::lookup {} intranet-helpdesk.Queue Queue]"} {options $ticket_queue_options}}
    }

    template::element::set_value $form_id ticket_status_id $ticket_status_id
    template::element::set_value $form_id ticket_type_id $ticket_type_id
    template::element::set_value $form_id ticket_queue_id $ticket_queue_id
}

template::element::set_value $form_id mine_p $mine_p


im_dynfield::append_attributes_to_form \
    -object_type $object_type \
    -form_id $form_id \
    -object_id 0 \
    -advanced_filter_p 1 \
    -search_p 1

# Set the form values from the HTTP form variable frame
im_dynfield::set_form_values_from_http -form_id $form_id
im_dynfield::set_local_form_vars_from_http -form_id $form_id
array set extra_sql_array [im_dynfield::search_sql_criteria_from_form \
			       -form_id $form_id \
			       -object_type $object_type
]

#ToDo: Export the extra DynField variables into form's "export" variable list

# ---------------------------------------------------------------
# Generate SQL Query
# ---------------------------------------------------------------

set criteria [list]
if { ![empty_string_p $ticket_status_id] && $ticket_status_id > 0 } {
    lappend criteria "t.ticket_status_id in ([join [im_sub_categories $ticket_status_id] ","])"
}
if { ![empty_string_p $ticket_type_id] && $ticket_type_id != 0 } {
    lappend criteria "t.ticket_type_id in ([join [im_sub_categories $ticket_type_id] ","])"
}
if { ![empty_string_p $ticket_queue_id] && $ticket_queue_id != 0 } {
    lappend criteria "t.ticket_queue_id = :ticket_queue_id"
}
if {0 != $assignee_id && "" != $assignee_id} {
    lappend criteria "t.ticket_assignee_id = :assignee_id"
}
if { ![empty_string_p $customer_id] && $customer_id != 0 } {
    lappend criteria "p.company_id = :customer_id"
}
if { ![empty_string_p $customer_contact_id] && $customer_contact_id != 0 } {
    lappend criteria "t.ticket_customer_contact_id = :customer_contact_id"
}
if { ![empty_string_p $letter] && [string compare $letter "ALL"] != 0 && [string compare $letter "SCROLL"] != 0 } {
    lappend criteria "im_first_letter_default_to_a(t.ticket_name)=:letter"
}

switch $mine_p {
    "all" { }
    "queue" {
	lappend criteria "(
		t.ticket_assignee_id = :current_user_id 
		OR t.ticket_customer_contact_id = :current_user_id
		OR t.ticket_queue_id in (
			select distinct
				g.group_id
			from	acs_rels r, groups g 
			where	r.object_id_one = g.group_id and
				r.object_id_two = :current_user_id
		)
	)"
    }
    "mine" {
	lappend criteria "(t.ticket_assignee_id = :current_user_id OR t.ticket_customer_contact_id = :current_user_id)"
    }
    "default" { ad_return_complaint 1 "Error:<br>Invalid variable mine_p = '$mine_p'" }
}





set order_by_clause "order by lower(t.ticket_id) DESC"
switch [string tolower $order_by] {
    "creation date" { set order_by_clause "order by p.start_date DESC" }
    "type" { set order_by_clause "order by ticket_type" }
    "status" { set order_by_clause "order by ticket_status_id" }
    "customer" { set order_by_clause "order by lower(company_name)" }
}

# ---------------------------------------------------------------
#
# ---------------------------------------------------------------

set where_clause [join $criteria " and\n            "]
set extra_select [join $extra_selects ",\n\t"]
set extra_from [join $extra_froms ",\n\t"]
set extra_where [join $extra_wheres "and\n\t"]

if { ![empty_string_p $where_clause] } { set where_clause " and $where_clause" }
if { ![empty_string_p $extra_select] } { set extra_select ",\n\t$extra_select" }
if { ![empty_string_p $extra_from] } { set extra_from ",\n\t$extra_from" }
if { ![empty_string_p $extra_where] } { set extra_where ",\n\t$extra_where" }


# ---------------------------------------------------------------
# 
# ---------------------------------------------------------------

# Create a ns_set with all local variables in order to pass it to the SQL query
set form_vars [ns_set create]
foreach varname [info locals] {

    # Don't consider variables that start with a "_", that
    # contain a ":" or that are array variables:
    if {"_" == [string range $varname 0 0]} { continue }
    if {[regexp {:} $varname]} { continue }
    if {[array exists $varname]} { continue }

    # Get the value of the variable and add to the form_vars set
    set value [expr "\$$varname"]
    ns_set put $form_vars $varname $value
}


# Deal with DynField Vars and add constraint to SQL
# Add the DynField variables to $form_vars
set dynfield_extra_where $extra_sql_array(where)
set ns_set_vars $extra_sql_array(bind_vars)
set tmp_vars [util_list_to_ns_set $ns_set_vars]
set tmp_var_size [ns_set size $tmp_vars]
for {set i 0} {$i < $tmp_var_size} { incr i } {
    set key [ns_set key $tmp_vars $i]
    set value [ns_set get $tmp_vars $key]
    ns_set put $form_vars $key $value
}

# Add the additional condition to the "where_clause"
if {"" != $dynfield_extra_where} {
    append where_clause "
	    and ticket_id in $dynfield_extra_where
    "
}



# ---------------------------------------------------------------
#
# ---------------------------------------------------------------

set sql "
	        SELECT
			t.*,
	                im_category_from_id(t.ticket_type_id) as ticket_type,
	                im_category_from_id(t.ticket_status_id) as ticket_status,
	                im_category_from_id(t.ticket_prio_id) as ticket_prio,
			im_name_from_user_id(t.ticket_customer_contact_id) as ticket_customer_contact,
			im_name_from_user_id(t.ticket_assignee_id) as ticket_assignee,
			(select group_name from groups where group_id = ticket_queue_id) as ticket_queue_name,
	                p.*,
	                to_char(p.start_date, 'YYYY-MM-DD') as start_date_formatted,
	                to_char(p.end_date, 'YYYY-MM-DD') as end_date_formatted,
	                to_char(t.ticket_alarm_date, 'YYYY-MM-DD') as ticket_alarm_date_formatted,
			ci.*,
			c.company_name,
			sla.project_id as sla_id,
			sla.project_name as sla_name
			$extra_select
	        FROM
			im_projects p,
			im_tickets t
			LEFT OUTER JOIN im_projects sla ON (t.ticket_sla_id = sla.project_id)
			LEFT OUTER JOIN im_conf_items ci ON (t.ticket_conf_item_id = ci.conf_item_id),
	                im_companies c
			$extra_from
	        WHERE
	                p.company_id = c.company_id
			and t.ticket_id = p.project_id
			and p.project_type_id = [im_project_type_ticket]
	                $where_clause
			$extra_where
		$order_by_clause
"


# ---------------------------------------------------------------
# 5a. Limit the SQL query to MAX rows and provide << and >>
# ---------------------------------------------------------------

if {[string equal $letter "ALL"]} {
    # Set these limits to negative values to deactivate them
    set total_in_limited -1
    set how_many -1
    set selection $sql
} else {
    # We can't get around counting in advance if we want to be able to
    # sort inside the table on the page for only those users in the
    # query results
    set total_in_limited [db_string total_in_limited "
        select count(*)
        from ($sql) s
    "]
    set selection [im_select_row_range $sql $start_idx $end_idx]
}	


# ----------------------------------------------------------
# Do we have to show administration links?

ns_log Notice "/intranet/ticket/index: Before admin links"
set admin_html "<ul>"

if {[im_permission $current_user_id "add_tickets"]} {
    append admin_html "<li><a href=\"/intranet-helpdesk/new\">[lang::message::lookup "" intranet-helpdesk.Add_a_new_ticket "New Ticket"]</a>\n"

    set wf_oid_col_exists_p [util_memoize "db_column_exists wf_workflows object_type"]
    if {$wf_oid_col_exists_p} {
	set wf_sql "
		select	t.pretty_name as wf_name,
			w.*
		from	wf_workflows w,
			acs_object_types t
		where	w.workflow_key = t.object_type
			and w.object_type = 'im_ticket'
	"
	db_foreach wfs $wf_sql {
	    set new_from_wf_url [export_vars -base "/intranet/tickets/new" {workflow_key}]
	    append admin_html "<li><a href=\"$new_from_wf_url\">[lang::message::lookup "" intranet-helpdesk.New_workflow "New %wf_name%"]</a>\n"
	}
    }
}

# Append user-defined menus
set bind_vars [ad_tcl_vars_to_ns_set]
append admin_html [im_menu_ul_list -no_uls 1 "tickets_admin" $bind_vars]

# Close the admin_html section
append admin_html "</ul>"


# ---------------------------------------------------------------
# 7. Format the List Table Header
# ---------------------------------------------------------------

# Set up colspan to be the number of headers + 1 for the # column
ns_log Notice "/intranet/ticket/index: Before format header"
set colspan [expr [llength $column_headers] + 1]

set table_header_html ""
#<tr>
#  <td align=center valign=top colspan=$colspan><font size=-1>
#    [im_groups_alpha_bar [im_ticket_group_id] $letter "start_idx"]</font>
#  </td>
#</tr>"

# Format the header names with links that modify the
# sort order of the SQL query.
#
set url "index?"
set query_string [export_ns_set_vars url [list order_by]]
if { ![empty_string_p $query_string] } {
    append url "$query_string&"
}

append table_header_html "<tr>\n"
foreach col $column_headers {
    regsub -all " " $col "_" col_txt
    set col_txt [lang::message::lookup "" intranet-helpdesk.$col_txt $col]
    if { [string compare $order_by $col] == 0 } {
	append table_header_html "  <td class=rowtitle>$col_txt</td>\n"
    } else {
	append table_header_html "  <td class=rowtitle><a href=\"${url}order_by=[ns_urlencode $col]\">$col_txt</a></td>\n"
    }
}
append table_header_html "</tr>\n"


# ---------------------------------------------------------------
# Format the Result Data
# ---------------------------------------------------------------

set table_body_html ""
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set ctr 0
set idx $start_idx
db_foreach tickets_info_query $selection -bind $form_vars {

    set url [im_maybe_prepend_http $url]
    if { [empty_string_p $url] } {
	set url_string "&nbsp;"
    } else {
	set url_string "<a href=\"$url\">$url</a>"
    }

    # Append together a line of data based on the "column_vars" parameter list
    set row_html "<tr$bgcolor([expr $ctr % 2])>\n"
    foreach column_var $column_vars {
	append row_html "\t<td valign=top>"
	set cmd "append row_html $column_var"
	eval "$cmd"
	append row_html "</td>\n"
    }
    append row_html "</tr>\n"
    append table_body_html $row_html

    incr ctr
    if { $how_many > 0 && $ctr > $how_many } {
	break
    }
    incr idx
}

# Show a reasonable message when there are no result rows:
if { [empty_string_p $table_body_html] } {
    set table_body_html "
        <tr><td colspan=$colspan><ul><li><b>There are currently no tickets matching the selected criteria</b></ul></td></tr>"
}

if { $end_idx < $total_in_limited } {
    # This means that there are rows that we decided not to return
    # Include a link to go to the next page
    set next_start_idx [expr $end_idx + 0]
    set next_page_url "index?start_idx=$next_start_idx&amp;[export_ns_set_vars url [list start_idx]]"
} else {
    set next_page_url ""
}

if { $start_idx > 0 } {
    # This means we didn't start with the first row - there is
    # at least 1 previous row. add a previous page link
    set previous_start_idx [expr $start_idx - $how_many]
    if { $previous_start_idx < 0 } { set previous_start_idx 0 }
    set previous_page_url "index?start_idx=$previous_start_idx&amp;[export_ns_set_vars url [list start_idx]]"
} else {
    set previous_page_url ""
}


# ---------------------------------------------------------------
# Format Table Continuation
# ---------------------------------------------------------------

# Check if there are rows that we decided not to return
# => include a link to go to the next page
#
if {$total_in_limited > 0 && $end_idx < $total_in_limited} {
    set next_start_idx [expr $end_idx + 0]
    set next_page "<a href=index?start_idx=$next_start_idx&amp;[export_ns_set_vars url [list start_idx]]>Next Page</a>"
} else {
    set next_page ""
}

# Check if this is the continuation of a table (we didn't start with the
# first row - there is at least 1 previous row.
# => add a previous page link
#
if { $start_idx > 0 } {
    set previous_start_idx [expr $start_idx - $how_many]
    if { $previous_start_idx < 0 } { set previous_start_idx 0 }
    set previous_page "<a href=index?start_idx=$previous_start_idx&amp;[export_ns_set_vars url [list start_idx]]>Previous Page</a>"
} else {
    set previous_page ""
}

set table_continuation_html "
<tr>
  <td align=center colspan=$colspan>
    [im_maybe_insert_link $previous_page $next_page]
  </td>
</tr>"


# ---------------------------------------------------------------
# Navbar
# ---------------------------------------------------------------

set menu_select_label ""
set ticket_navbar_html [im_project_navbar $letter "/intranet/tickets/index" $next_page_url $previous_page_url [list start_idx order_by how_many view_name letter ticket_status_id] $menu_select_label]

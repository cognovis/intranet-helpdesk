<?xml version="1.0"?>
<queryset>
   <rdbms><type>postgresql</type><version>7.1</version></rdbms>


<fullquery name="ticket_insert">
    <querytext>
	SELECT im_ticket__new (
		:ticket_id,		-- p_ticket_id
		'im_ticket',		-- object_type
		now(),			-- creation_date
		0,			-- creation_user
		'0.0.0.0',		-- creation_ip
		null,			-- context_id

		:ticket_name,
		:ticket_customer_id,
		:ticket_type_id,
		:ticket_status_id
	);

    </querytext>
</fullquery>


<fullquery name="ticket_delete">
    <querytext>
    BEGIN
	PERFORM im_ticket__delete (:ticket_id);
	return 0;
    END;
    </querytext>
</fullquery>


<fullquery name="ticket_update">
    <querytext>
	update im_tickets set
		ticket_type_id		= :ticket_type_id,
		ticket_status_id	= :ticket_status_id
	where
		ticket_id = :ticket_id;
    </querytext>
</fullquery>


<fullquery name="project_update">
    <querytext>
	update im_projects set
		project_name		= :ticket_name,
		project_nr		= :ticket_nr
	where
		project_id = :ticket_id;
    </querytext>
</fullquery>


</queryset>
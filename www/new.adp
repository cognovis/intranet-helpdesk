<master src="../../intranet-core/www/master">
<property name="title">@page_title@</property>
<property name="context">@context;noquote@</property>
<property name="main_navbar_label">projects</property>
<property name="focus">@focus;noquote@</property>
<property name="sub_navbar">@sub_navbar;noquote@</property>

<if @message@ not nil>
  <div class="general-message">@message@</div>
</if>

<if @form_mode@ eq "display" >
      <%= [im_component_bay top] %>
</if>
<table width="100%">
  <tr valign="top">
    <td width="50%">
      <%= [im_box_header $page_title] %>
      <formtemplate id="ticket"></formtemplate></font>
      <%= [im_box_footer] %>
	<if @form_mode@ eq "display" >
	      <%= [im_component_bay left] %>
	</if>
    </td>
    <td width="50%">
	<if @form_mode@ eq "display" >
	      <%= [im_component_bay right] %>
	</if>
    </td>
  </tr>
</table>

<if @form_mode@ eq "display" >
      <%= [im_component_bay bottom] %>
</if>
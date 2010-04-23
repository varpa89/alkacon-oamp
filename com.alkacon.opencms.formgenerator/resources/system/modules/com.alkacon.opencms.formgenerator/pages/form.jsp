<%@page buffer="none" session="false"
	import="org.opencms.i18n.*,com.alkacon.opencms.formgenerator.*,java.util.*, org.opencms.util.*"%>
<%

	///////////////////////////////////////////////////////////////////////////
	// BEGIN: This is for compatibility with the survey module: DON'T CHANGE //
	///////////////////////////////////////////////////////////////////////////
		// initialize the form handler
		CmsFormHandler cms = null;
		CmsFormHandler cmsFf = (CmsFormHandler)pageContext.getAttribute("cmsF");
		if (cmsFf == null) {
			cms = new CmsFormHandler(pageContext, request, response);
		} else {
			cms = cmsFf;
		}
	/////////
	// END //
	/////////

	boolean isOffline = !cms.getRequestContext().currentProject().isOnlineProject();

    // get the localized messages to create the form
    if (pageContext.getAttribute("addMessage") != null) {
        cms.addMessages(new CmsMessages(
            (String)pageContext.getAttribute("addMessage"),
            cms.getRequestContext().getLocale()));
    }
    CmsMessages messages = cms.getMessages();
    
    // is there a paging used
    boolean paging = false;

    // In case of downloading the csv file from database no template must be included: 
    boolean showTemplate = cms.showTemplate();
    String template = "";
    if (showTemplate) {
        // get the template to display
        template = cms.property("template", "search");
        // include the template head
        cms.include(template, "head");
    }
    boolean showForm = cms.showForm();

    if (!showForm) {
        // form has been submitted with correct values, decide further actions
        if (cms.showCheck()) {
            // show optional check page
            request.setAttribute("formhandler", cms);
            cms.include("/system/modules/com.alkacon.opencms.formgenerator/elements/check.jsp");
        } else if (cms.showDownloadData()) {
            cms.include("/system/modules/com.alkacon.opencms.formgenerator/elements/datadownload.jsp");
        } else {
            // try to send a notification email with the submitted form field values
            if (cms.sendData()) {
                // successfully sent mail, show confirmation end page
                if (cms.getFormConfiguration().hasTargetUri()) {
                    response.sendRedirect(cms.link(cms.getFormConfiguration().getTargetUri()));
                } else {
                    request.setAttribute("formhandler", cms);
                    cms.include("/system/modules/com.alkacon.opencms.formgenerator/elements/confirmation.jsp");
                }
                // prepare the webform action class if configured
                cms.prepareAfterWebformAction();
            } else {
                // failure sending mail, show error output
%>
<%=messages.key("form.error.mail.headline.start")%><%=messages.key("form.error.mail.headline")%><%=messages.key("form.error.mail.headline.end")%>
<%=messages.key("form.error.mail.text.start")%><%=messages.key("form.error.mail.text")%><%=messages.key("form.error.mail.text.end")%>

<!--
			Error description: <%=(String)cms.getErrors().get("sendmail")%>
			//-->
<%
    }
        }

    } else {
        // get the configured form elements
        CmsForm formConfiguration = cms.getFormConfiguration();
        List fields = formConfiguration.getFields();
        pageContext.setAttribute("fieldssize", fields.size());

        String enctype = "";
        Iterator iter = fields.iterator();
        while (iter.hasNext()) {
            I_CmsField tmp = (I_CmsField)iter.next();
            if (tmp.getType().equals("file")) {
                enctype = "enctype=\"multipart/form-data\"";
            }
        }

        // show form text
        out.print(formConfiguration.getFormText());

        // show global error message if validation failed
        if (cms.hasValidationErrors()) {
            out.print("<p>");
            out.print(messages.key("form.html.label.error.start"));
            out.print(messages.key("form.error.message"));
            out.print(messages.key("form.html.label.error.end"));
            out.println("</p>");
        }

        // create the form head
%>
<form name="emailform"
	action="<%=cms.link(cms.getRequestContext().getUri())%>"
	method="post" <%=enctype%>
	<%=formConfiguration.getFormAttributes()%>><!-- Hidden form fields:  -->
<input type="hidden" name="<%=CmsFormHandler.PARAM_FORMACTION%>"
	id="<%=CmsFormHandler.PARAM_FORMACTION%>"
	value="<%=CmsFormHandler.ACTION_SUBMIT%>" /> <%=messages.key("form.html.start")%>
<%
    // create the html output to display the form fields
        int pos = 0;
	    int fieldNr = 0;
        int place = 0;
        int currPage = 1;
        int pagingPos = 0;
        if (cms.getParameterMap().containsKey("back") && cms.getParameterMap().containsKey("page")) {
        	String pagingString[] = (String[])cms.getParameterMap().get("page");
        	currPage = new Integer(pagingString[0]).intValue();
        	currPage = CmsPagingField.getPreviousPage(currPage);
        } else if (cms.getParameterMap().containsKey("page") && !cms.hasValidationErrors()) {
        	String pagingString[] = (String[])cms.getParameterMap().get("page");
        	currPage = new Integer(pagingString[0]).intValue();
        	currPage = CmsPagingField.getNextPage(currPage);
        } else if (cms.getParameterMap().containsKey("page") && cms.hasValidationErrors()) {
        	String pagingString[] = (String[])cms.getParameterMap().get("page");
        	currPage = new Integer(pagingString[0]).intValue();
        }
        pagingPos = CmsPagingField.getFirstFieldPosFromPage(cms, currPage);
        fieldNr = pagingPos;
        pageContext.setAttribute("page", currPage);
        for (int i = pagingPos, n = fields.size(); i < n; i++) {
            fieldNr += 1;
            // loop through all form input fields 
            I_CmsField field = (I_CmsField)fields.get(i);

            if (i == n - 1)
               	place = 1; //the last one must close the tr
            field.setPlaceholder(place);
            field.setPosition(pos);
            field.setFieldNr(fieldNr);
            String errorMessage = (String)cms.getErrors().get(field.getName());
            String infoMessage = (String)cms.getInfos().get(field.getName());
            // validate the file upload field here already because of the lost values ion these fields
            if (field instanceof CmsFileUploadField) {
            	infoMessage = field.validateForInfo(cms);
            }
	    out.println(field.buildHtml(cms, messages, errorMessage, formConfiguration.isShowMandatory(), infoMessage));
            pos = field.getPosition();
            place = field.getPlaceholder();
            // if there is a paging field do not show the following fields
            if (field instanceof CmsPagingField) {
               	paging = true;
            	break;
            }
        }

        // show form footer text
        out.print(messages.key("form.html.row.middle.start"));
        out.print(formConfiguration.getFormMiddleText());
        out.print(messages.key("form.html.row.middle.end"));

        // create the form foot 
        if (formConfiguration.hasMandatoryFields() && formConfiguration.isShowMandatory()) {
%><%=messages.key("form.html.row.start")%> <%=messages.key("form.html.mandatory.start")%><%=messages.key("form.message.mandatory")%><%=messages.key("form.html.mandatory.end")%>
<%=messages.key("form.html.row.end")%> <%
     } if (!paging) {
     %><%=messages.key("form.html.row.start")%> <%=messages.key("form.html.button.start")%> <%
     if (cms.getParameterMap().containsKey("page")) {
          out.println(CmsPagingField.appendHiddenFields(cms, messages, fields.size()));
     	%><input type='hidden' name='page' value='${page}' />
     	  <input type='hidden' name='finalpage' value='true' />
     	  <input type='submit' value='<%=messages.key("form.button.prev")%>' name='back' class='formbutton prevbutton' /> <%
     } %>
   <input type="submit" value="<%=messages.key("form.button.submit")%>" class="formbutton submitbutton" />  <%  
   }
   if (formConfiguration.isShowReset() && !paging) {
%>&nbsp;<input type="reset"
	value="<%=messages.key("form.button.reset")%>"
	class="formbutton resetbutton" />
<%
    }
%><%=messages.key("form.html.button.end")%> <%=messages.key("form.html.row.end")%>
<%
    if (isOffline && formConfiguration.isTransportDatabase() && !paging) {
%> <%=messages.key("form.html.row.start")%>
<%=messages.key("form.html.button.start")%><input type="submit"
	onClick="javascript:document.getElementById('<%=CmsFormHandler.PARAM_FORMACTION%>').value='<%=CmsFormHandler.ACTION_DOWNLOAD_DATA_1%>';"
	value="<%=messages.key("form.button.downloaddata")%>"
	class="formbutton downloadbutton" /><%=messages.key("form.html.button.end")%>
<%=messages.key("form.html.row.end")%>
<%
    }
%> <%=messages.key("form.html.end")%></form>
<%
    // show form footer text
        out.print(formConfiguration.getFormFooterText());

    }
    if (showTemplate) {
        // include the template foot
        cms.include(template, "foot");
    }
%>

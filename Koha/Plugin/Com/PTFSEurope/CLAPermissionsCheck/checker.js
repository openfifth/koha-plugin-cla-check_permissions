(function () {
    $(document).ready(function () {

        /**
         * ILL Request creation page
         */
        if (window.location.href.includes("ill-requests.pl") && $("#create_form").length && $('input[name="backend"][value="Standard"]').length) {
            $('#create_form').after(cla_modal_tmpl);
            ["issn", "isbn"].forEach(function (id) {
                if ($("#" + id).length) {
                    $('#' + id).after(cla_button_tmpl);
                    if(!$("#" + id).val()){
                        $("#cla_check_permissions_button").prop("disabled", true);
                    }else{
                        updateButtonAttributes(id);
                    }
                    $("#" + id).on("keyup change", function () {
                        if(!$("#" + id).val()){
                            $("#cla_check_permissions_button").prop("disabled", true);
                        }else{
                            $("#cla_check_permissions_button").prop("disabled", false);
                        }
                        updateButtonAttributes(id);
                    });
                }
            });

            function updateButtonAttributes(id) {
                $("#cla_check_permissions_button").attr("data-type", id);
                $("#cla_check_permissions_button").attr("data-identifier", $("#" + id).val());
                $("#cla_check_permissions_button").attr("data-licence", cla_permissions_check_plugin_license);
            }
        }

        /**
         * Modal for checkPermissions
         */
        $("#checkPermissions").on("show.bs.modal", function (event) {
            let button = $(event.relatedTarget);
            let type = button.attr("data-type");
            let identifier = button.attr("data-identifier");
            let licence = button.attr("data-licence");
            checkPermissions(type, identifier, licence);
        });

        /**
         * Helper functions
         */
        function checkPermissions(type, identifier, licence) {
            let baseUrl = "/api/v1/contrib/cla_check_permissions/proxy/";

            let url =
                baseUrl + type.toUpperCase() + "/" + identifier + "/" + licence;

            $.get({
                url: url,
                type: 'GET',
                beforeSend: function (xhr) {
                    $("#cla_loading").css("display", "block");
                    $("#cla_request_complete").css("display", "none");
                    $("#cla_error_message").css("display", "none");
                    $("#dataPreview .modal-body, #cla_tabs_list, #cla_tabs_content").empty();
                }
            })
                .done(function (r) {
                    $("#cla_loading").css("display", "none");
                    $("#cla_request_complete").css("display", "block");
                    $("#dataPreview .modal-body").html(r.responseJSON);
                    $("#cla_tabs_list").html(tabs(r.usagesSummary));
                    $("#cla_tabs_content").html(tabsContent(r.usagesSummary));
                })
                .error(function (e) {
                    $("#cla_error_message")
                        .text(e.responseJSON?.message || e.statusText)
                        .css("display", "block");
                    $("#cla_loading").css("display", "none");
                });
        }

        function tabs(summary) {
            return summary.map(function (item, index) {
                if (item.reportType != "Show Nothing") {
                    if (index === 0) {
                        return (
                            '<li role="presentation" class="nav-item"><a class="nav-link active" href="#" data-bs-toggle="tab" data-bs-target="#cla_tab_' +
                            index +
                            '_panel" id="cla_tab_' +
                            index +
                            '-tab" data-tabname="cla_tab_' +
                            index +
                            '" role="tab" data-toggle="tab">' +
                            item.usageType +
                            "</a>" +
                            "</li>"
                        );
                    } else {
                        return (
                            '<li role="presentation" class="nav-item"><a class="nav-link" href="#" data-bs-toggle="tab" data-bs-target="#cla_tab_' +
                            index +
                            '_panel" id="cla_tab_' +
                            index +
                            '-tab" data-tabname="cla_tab_' +
                            index +
                            '" role="tab" data-toggle="tab">' +
                            item.usageType +
                            "</a>" +
                            "</li>"
                        );
                    }
                }
            });
        }

        function tabsContent(summary) {
            var content = "";
            summary.forEach(function (item, index) {
                if (item.reportType != "Show Nothing") {
                    var h = item.header;
                    if (index === 0) {
                        content +=
                            '<div id="cla_tab_' +
                            index +
                            '_panel" role="tabpanel" class="tab-pane active">';
                    } else {
                        content +=
                            '<div id="cla_tab_' +
                            index +
                            '_panel" role="tabpanel" class="tab-pane">';
                    }
                    content += getPermitted(item.reportType);
                    content += "<h1>" + h.title + "</h1>";
                    content += "<h2>" + h.introduction + "</h2>";
                    if (item.usageDetails) {
                        content += '<ul class="cla_usage_details">';
                        content += item.usageDetails
                            .map(function (detail) {
                                return "<li>" + detail.title + "</li>";
                            })
                            .join("");
                        content += "</ul>";
                    }
                    var rest = item.footer.restrictions;
                    var terms = item.footer.terms;
                    content += "<h3>Restrictions</h3>";
                    content +=
                        '<p class="cla_restrictions">' +
                        (!!rest ? rest : "None") +
                        "</p>";
                    content += "<h3>Terms</h3>";
                    content +=
                        '<p class="cla_terms">' +
                        (!!terms ? terms : "None") +
                        "</p>";
                    content += "</div>";
                }
            });
            return content.length > 0 ? content : null;
        }

        function getPermitted(val) {
            if (val == "Permitted") {
                return (
                    '<span class="text-success fa fa-4x fa-border fa-pull-right fa-check cla_yes" title="' +
                    val +
                    '"></span>'
                );
            } else if (val == "available") {
                return "";
            } else {
                return '<span class="text-danger fa fa-4x fa-border fa-pull-right fa-ban cla_no" title="' +
                    val +
                    '"></span>';
            }
        }
    });
})();

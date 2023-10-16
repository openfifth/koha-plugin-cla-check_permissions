$(document).ready(function () {
    $("#checkPermissions").on("show.bs.modal", function (event) {
        console.log("Triggered checkPermissions Modal");
        let modal = $(this);
        let button = $(event.relatedTarget);

        let type = button.data("type");
        let identifier = button.data("identifier");
        let licence = button.data("licence");

        let baseUrl = "/api/v1/contrib/cla_check_permissions/proxy/";

        let url =
            baseUrl + type.toUpperCase() + "/" + identifier + "/" + licence;

        $.get(url)
            .done(function (r) {
                $("#cla_loading").css("display", "none");
                $("#cla_request_complete").css("display", "block");
                $("#dataPreview .modal-body").html(r.responseJSON);
                $("#cla_tabs_list").html(tabs(r.usagesSummary));
                $("#cla_tabs_content").html(tabsContent(r.usagesSummary));
            })
            .error(function (e) {
                $("#cla_error_message")
                    .text(e.responseJSON.message)
                    .css("display", "block");
                $("#cla_loading").css("display", "none");
            });

        function tabs(summary) {
            return summary.map(function (item, index) {
                if (item.reportType != "Show Nothing") {
                    if (index === 0) {
                        return (
                            '<li role="presentation" class="active"><a href="#cla_tab_' +
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
                            '<li role="presentation"><a href="#cla_tab_' +
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
                    '<span class="fa fa-4x fa-border fa-pull-right fa-check cla_yes" title="' +
                    val +
                    '"></span>'
                );
            } else if (val == "available") {
                return "";
            } else {
                '<span class="fa fa-4x fa-border fa-pull-right fa-cross cla_no" title="' +
                    val +
                    '"></span>';
            }
        }
    });
});

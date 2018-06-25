(function() {

  var baseUrl =
    'https://api.cla.co.uk/check-permissions/v1/GetPermissionByIdentifier/';

  var dataEl = $('#cla_check_permissions_id');
  var idType = dataEl.data('identifier_type');
  var id = dataEl.data('identifier');
  var key = dataEl.data('key');
  var hash = dataEl.data('hash');
  var licence = dataEl.data('licence');
  if (!id || !idType || !key || !licence) {
    dataEl.css('display', 'none');
    $('#cla_loading').css('display', 'none');
    $('#cla_missing_params').css('display', 'block');
    return;
  }

  var url = baseUrl + idType.toUpperCase() + '/' + id + '/' + licence +
    '?usageTypes=1,2&messageId=' + hash + '&htmlToggle=true';

  function tabs(summary) {
    return summary.map(function(item, index) {
      if (item.reportType != 'Show Nothing') {
        return '<li><a href="#cla_tab_' + index + '">' + item.usageType + '</a>' + '</li>';
      }
    });
  }

  function tabsContent(summary) {
    var content = '';
    summary.forEach(function(item, index) {
      if (item.reportType != 'Show Nothing') {
        var h = item.header;
        content += '<div id="cla_tab_' + index + '">';
        content += getPermitted(item.reportType);
        content += '<h1>' + h.title + '</h1>';
        content += '<h2>' + h.introduction + '</h2>';
        if (item.usageDetails) {
          content += '<ul class="cla_usage_details">';
          content += item.usageDetails.map(function(detail) {
            return '<li>' + detail.title + '</li>';
          }).join('');
          content += '</ul>';
        }
        var rest = item.footer.restrictions;
        var terms = item.footer.terms;
        content += '<h3>Restrictions</h3>';
        content += '<p class="cla_restrictions">' + (!!rest ? rest : 'None') + '</p>';
        content += '<h3>Terms</h3>';
        content += '<p class="cla_terms">' + (!!terms ? terms : 'None') + '</p>';
        content += '</div>';
      }
    });
    return content.length > 0 ? content : null;
  }

  function getPermitted(val) {
    if (val == 'Permitted') {
      return '<span class="fa fa-4x fa-border fa-pull-right fa-check cla_yes" title="' + val + '"></span>';
    } else if (val == 'available') {
      return '';
    } else {
      '<span class="fa fa-4x fa-border fa-pull-right fa-cross cla_no" title="' + val + '"></span>';
    }
  }

  $.ajaxSetup({
      headers: {
          'Ocp-Apim-Subscription-Key': key
      }
  });

  $.get(url)
    .done(function(r) {
        dataEl.css('display', 'none');
        $('#cla_loading').css('display', 'none');
        $('#cla_request_complete').css('display', 'block');
        $('#dataPreview .modal-body').html(r.responseJSON);
        $('#dataPreview').modal({show:true});
        $('#cla_tabs_list').html(tabs(r.usagesSummary));
        $('#cla_tabs_content').html(tabsContent(r.usagesSummary));
        $('#cla_tabs').tabs();
    })
    .error(function(e) {
        $('#cla_error_message')
            .text(e.responseJSON.message)
            .css('display', 'block');
        dataEl.css('display', 'none');
        $('#cla_loading').css('display', 'none');
    });

})();

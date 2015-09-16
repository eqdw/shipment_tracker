//= require jquery
//= require jquery_ujs
//= require bootstrap-sprockets
//= require bootstrap-editable
//= require bootstrap/tooltip

$(function() {
  $.fn.editable.defaults.ajaxOptions = {type: "PUT"};
  $.fn.editable.defaults.mode = 'inline';
  $('.js-editable').editable();
  $('[data-toggle=tooltip]').tooltip();
});

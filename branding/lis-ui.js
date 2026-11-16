/* LIS header controls: retain only notification bell and profile. */
(function(){
  function cleanHeader(){
    document.querySelectorAll('.head__actions .head__action').forEach(function(node){
      var isProfile = node.classList.contains('open--profile');
      var icon = node.querySelector('use');
      var href = icon && (icon.getAttribute('href') || icon.getAttribute('xlink:href') || '');
      var isBell = /bell/i.test(href) || /bell|notice|notification/i.test(node.className || '');
      if(isBell) node.classList.add('lis-keep-bell');
      node.style.setProperty('display', (isProfile || isBell) ? 'flex' : 'none', 'important');
    });
    document.querySelectorAll('.head__markers').forEach(function(node){
      node.style.setProperty('display','none','important');
    });
  }
  cleanHeader();
  if(document.body && window.MutationObserver){
    new MutationObserver(cleanHeader).observe(document.body,{childList:true,subtree:true,attributes:true,attributeFilter:['class']});
  }
  document.addEventListener('DOMContentLoaded',cleanHeader);
  window.addEventListener('load',cleanHeader);
})();

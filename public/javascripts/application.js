$(function(){	
	// tipTip all form fields
	$('input').tipTip();	
	$('textarea').tipTip();
	$('select').tipTip();
		
	// Patient search box
	$("#patient-search").autoSuggest("/patients/search", {startText: "Enter the patient name or UID", minChars: 2, selectionLimit: 1, selectedValuesProp: "data", selectedItemProp: "name", searchObjProps: "value,name", resultClick: function(data){ window.location.href = "/patients/show/" + data.attributes.data; }});
	
	// This function prevents the session from ending
	window.iCallServerId = setInterval(function (){ var remoteURL = '/'; $.get(remoteURL); }, 900000);
});	

// Google Analytics code
var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));

try {
var pageTracker = _gat._getTracker("UA-2308620-65");
pageTracker._setDomainName(".odonto.me");
pageTracker._trackPageview();
} catch(err) {}
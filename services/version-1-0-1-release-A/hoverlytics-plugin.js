/* (c) 2013 Patrick Smith */"Copyright 2013 Patrick Smith";function hoverlyticsSetUp(){var e=hoverlyticsPageViewer.localProxyFileURL,t=hoverlyticsPageViewer.getGoogleAnalyticsProfileID("hoverlyticsGoogleAnalyticsProfileID"),n='{"sourceProxyURL":"'+e+'"'+(t?',"googleAnalyticsProfileID":"'+t+'"':"")+"}",r=hoverlyticsPageViewer.baseURL,i=r+"#"+encodeURIComponent(n),s=hoverlyticsPageViewer.$iframe=jQuery("<iframe>",{id:"hoverlyticsPageViewerIFrame",name:"hoverlyticsPageViewerIFrame",width:250,height:348,src:i,frameborder:"0",scrolling:"no"}),o=hoverlyticsPageViewer.$holder=jQuery("<div></div>",{id:"hoverlyticsPageViewerHolder"});hoverlyticsPageViewerUpdateAlignment();o.toggleClass("demo",!!hoverlyticsPageViewer.isDemo);o.append(s);o.appendTo("body");var u=jQuery("<a></a>",{id:"hoverlyticsPageViewerToggleButton",href:"#"});u.on("click",hoverlyticsPageViewerToggleButtonClicked);var a=jQuery("<a></a>",{id:"hoverlyticsPageViewerSettingsButton","class":"icon-cog",href:"#settings"});a.on("click",hoverlyticsPageViewerSettingsButtonClicked);var f=jQuery("<div></div>",{id:"hoverlyticsPageViewerButtonBar"});f.append(u,a);o.append(f);f.on("mouseover",function(e){hoverlyticsPageViewerChangeActive(!0)});var l=r+"services/proxy.html",c=hoverlyticsPageViewer.proxy=new Porthole.WindowProxy(l,"hoverlyticsPageViewerIFrame");c.addEventListener(hoverlyticsPageViewerReceivedMessage);hoverlyticsPageViewer.ready=!0;hoverlyticsPageViewerChangeEnabled(hoverlyticsPageViewer.getEnabled());hoverlyticsPageViewer.linkToLoad&&hoverlyticsChangeTargetPageLink(hoverlyticsPageViewer.linkToLoad)}function hoverlyticsPageViewerUpdateAlignment(e){var t=hoverlyticsPageViewer.$holder,n=hoverlyticsPageViewer.getAlignment();if(e&&e.previousAlignment){t.addClass("changingAlignment");var r={};r[e.previousAlignment]="-300px";t.animate(r,480,function(){t.toggleClass("alignedLeft",n==="left");t.toggleClass("alignedRight",n==="right");r[e.previousAlignment]="auto";r[n]="-300px";t.css(r);r[n]="0";t.animate(r,400,function(){t.removeClass("changingAlignment");r[e.previousAlignment]="";r[n]="";t.css(r)})})}else{t.toggleClass("alignedLeft",n==="left");t.toggleClass("alignedRight",n==="right")}hoverlyticsPageViewerToggleUpdateSettingsView()}function hoverlyticsPageViewerChangeActive(e){hoverlyticsPageViewer.$holder.toggleClass("active",e)}function hoverlyticsPageViewerChangeEnabled(e){e==null&&(e=!hoverlyticsPageViewer.getEnabled());hoverlyticsPageViewer.setEnabled(e);hoverlyticsPageViewer.$holder.toggleClass("enabled",e)}function hoverlyticsPageViewerToggleShowingSettings(){var e=jQuery("#hoverlyticsPageViewerSettings");if(e.size()===0){e=jQuery("<div></div>",{id:"hoverlyticsPageViewerSettings"});var t=jQuery("<a></a>",{id:"hoverlyticsPageViewerSettingsAlignLeft","data-icon":"\ue002"}).text("Align Left"),n=jQuery("<a></a>",{id:"hoverlyticsPageViewerSettingsAlignRight","data-icon":"\ue003"}).text("Align Right");e.append(t,n);t.on("click",function(e){hoverlyticsPageViewer.setAlignment("left")});n.on("click",function(e){hoverlyticsPageViewer.setAlignment("right")});hoverlyticsPageViewer.$holder.append(e);hoverlyticsPageViewerToggleUpdateSettingsView()}setTimeout(function(){e.toggleClass("active")},1)}function hoverlyticsPageViewerToggleUpdateSettingsView(){var e=hoverlyticsPageViewer.getAlignment();jQuery("#hoverlyticsPageViewerSettingsAlignLeft").toggleClass("selected",e==="left");jQuery("#hoverlyticsPageViewerSettingsAlignRight").toggleClass("selected",e==="right")}function hoverlyticsPageViewerToggleButtonClicked(e){e.preventDefault();hoverlyticsPageViewerChangeEnabled()}function hoverlyticsPageViewerSettingsButtonClicked(e){e.preventDefault();hoverlyticsPageViewerToggleShowingSettings()}function hoverlyticsMouseEnteredPageLink(e){if(!hoverlyticsPageViewer.getEnabled())return;var t=jQuery(e.target).closest("a[href]");hoverlyticsBeginTargetingLink(t)}function hoverlyticsMouseExitedPageLink(e){var t=jQuery(e.target);hoverlyticsCancelTargetingLink(t)}function hoverlyticsBeginTargetingLink(e){e=e.filter(":not([href^='#']):not([href^='mailto:'])");e=e.filter("[href*='"+location.hostname+"'], [href^='/']");e=e.filter(":not([href*='/wp-admin/'])");if(e.size()===0)return!1;if(e.data("hoverlyticsMouseIsTargeting"))return;if(hoverlyticsPageViewer.targetedLink){hoverlyticsCancelTargetingLink(hoverlyticsPageViewer.targetedLink);hoverlyticsPageViewer.targetedLink=null}e.data("hoverlyticsMouseIsTargeting",!0);hoverlyticsPageViewer.targetedLink=e;e.on("mouseout.hoverlyticsChecking",hoverlyticsMouseExitedPageLink);var t=hoverlyticsPageViewer.pageLinkTimeoutDuration,n=setTimeout(function(){hoverlyticsChangeTargetPageLink(e)},t);e.data("hoverlyticsTimeout",n)}function hoverlyticsCancelTargetingLink(e){var t=e.data("hoverlyticsTimeout");t&&clearTimeout(t);e.data("hoverlyticsMouseIsTargeting",!1);e.off(".hoverlyticsChecking")}function hoverlyticsChangeTargetPageLink(e){hoverlyticsPageViewer.$holder.addClass("messagePassed");if(hoverlyticsPageViewer.getEnabled())if(hoverlyticsPageViewer.proxy){hoverlyticsPageViewer.proxy.post({changePageURL:e.attr("href")});hoverlyticsPageViewerChangeActive(!0);jQuery(".hoverlyticsActiveLink").removeClass("hoverlyticsActiveLink");e.addClass("hoverlyticsActiveLink")}else hoverlyticsPageViewer.linkToLoad=e}function hoverlyticsPageViewerReceivedMessage(e){if(!e||!e.data)return;if(e.data.newProfileIDSelected){var t=e.data.newProfileIDSelected;hoverlyticsPageViewer.setGoogleAnalyticsProfileID(t)}else e.data.needsUser&&hoverlyticsPageViewerChangeActive(!0)}window.hoverlyticsPageViewer=jQuery.extend({getEnabled:function(){this.enabled==null&&(this.enabled=jQuery.cookie("hoverlyticsPageViewerEnabled")!="0");return this.enabled},setEnabled:function(e){jQuery.cookie("hoverlyticsPageViewerEnabled",e?"1":"0");this.enabled=e},defaultAlignment:"left",getAlignment:function(){this.alignment||(this.alignment=jQuery.cookie("hoverlyticsPageViewerAlignment")||this.defaultAlignment);return this.alignment},setAlignment:function(e){var t=this.alignment||null;if(this.alignment===e)return;jQuery.cookie("hoverlyticsPageViewerAlignment",e,{expires:1780,path:"/"});jQuery.cookie("hoverlyticsSettingsDidChange","1",{path:"/"});this.alignment=e;hoverlyticsPageViewerUpdateAlignment({previousAlignment:t})},getGoogleAnalyticsProfileID:function(){return jQuery.cookie("hoverlyticsGoogleAnalyticsProfileID")},setGoogleAnalyticsProfileID:function(e){jQuery.cookie("hoverlyticsGoogleAnalyticsProfileID",e,{expires:1780,path:"/"});jQuery.cookie("hoverlyticsSettingsDidChange","1",{path:"/"})}},window.hoverlyticsPageViewer||{});jQuery(document).on("mouseover","a[href]",hoverlyticsMouseEnteredPageLink);jQuery(function(){hoverlyticsSetUp()});
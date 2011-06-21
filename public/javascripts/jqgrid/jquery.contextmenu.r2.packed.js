// Compacted by ScriptingMagic.com
/*
 * ContextMenu - jQuery plugin for right-click context menus
 *
 * Author: Chris Domigan
 * Contributors: Dan G. Switzer, II
 * Parts of this plugin are inspired by Joern Zaefferer's Tooltip plugin
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Version: r2
 * Date: 16 July 2007
 *
 * For documentation visit http://www.trendskitchens.co.nz/jquery/contextmenu/
 *
 */
(function($){var a,b,c,d,e,f;var g={menuStyle:{listStyle:"none",padding:"1px",margin:"0px",backgroundColor:"#fff",border:"1px solid #999",width:"100px"},itemStyle:{margin:"0px",color:"#000",display:"block",cursor:"default",padding:"3px",border:"1px solid #fff",backgroundColor:"transparent"},itemHoverStyle:{border:"1px solid #0a246a",backgroundColor:"#b6bdd2"},eventPosX:"pageX",eventPosY:"pageY",shadow:true,onContextMenu:null,onShowMenu:null};$.fn.contextMenu=function(h,i){if(!a){a=$('<div id="jqContextMenu"></div>').hide().css({position:"absolute",zIndex:"500"}).appendTo("body").bind("click",function(j){j.stopPropagation()})}if(!b){b=$("<div></div>").css({backgroundColor:"#000",position:"absolute",opacity:0.2,zIndex:499}).appendTo("body").hide()}e=e||[];e.push({id:h,menuStyle:$.extend({},g.menuStyle,i.menuStyle||{}),itemStyle:$.extend({},g.itemStyle,i.itemStyle||{}),itemHoverStyle:$.extend({},g.itemHoverStyle,i.itemHoverStyle||{}),bindings:i.bindings||{},shadow:i.shadow||i.shadow===false?i.shadow:g.shadow,onContextMenu:i.onContextMenu||g.onContextMenu,onShowMenu:i.onShowMenu||g.onShowMenu,eventPosX:i.eventPosX||g.eventPosX,eventPosY:i.eventPosY||g.eventPosY});var j=e.length-1;$(this).bind("contextmenu",function(k){var l=(!!e[j].onContextMenu)?e[j].onContextMenu(k,this):true;if(l){display(j,this,k,i)}return false});return this};function display(h,i,j,k){var l=e[h];d=$("#"+l.id).find("ul:first").clone(true);d.css(l.menuStyle).find("li").css(l.itemStyle).hover(function(){$(this).css(l.itemHoverStyle)},function(){$(this).css(l.itemStyle)}).find("img").css({verticalAlign:"middle",paddingRight:"2px"});a.html(d);if(!!l.onShowMenu){a=l.onShowMenu(j,a)}$.each(l.bindings,function(m,n){$("#"+m,a).bind("click",function(o){hide();n(i,f)})});a.css({"left":j[l.eventPosX],"top":j[l.eventPosY]}).show();if(l.shadow){b.css({width:a.width(),height:a.height(),left:j.pageX+2,top:j.pageY+2}).show()}$(document).one("click",hide)}function hide(){a.hide();b.hide()}$.contextMenu={defaults:function(h){$.each(h,function(i,j){if(typeof j=="object"&&g[i]){$.extend(g[i],j)}else{g[i]=j}})}}})(jQuery);$(function(){$("div.contextMenu").hide()})
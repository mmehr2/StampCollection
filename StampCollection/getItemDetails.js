// For parsing any of the thousands of Bait-tov.com's individual Pic Details pages
// My main interest is in the Sets category (for now). There is a line with the following info:
/* Typical web source:
 </TABLE>
 7.11.1962/M. & G. Shamir/p72/15s 5t/bulletin 120/leaflet 29/<br/>
 
 RELATED ITEMS
*/
/*
 The line contains: actual date (FD I think, designer(s), plate #s, sheet format (stamps and tabs),bulletin #s(opt)/leaflet #s(opt)
 The separators are '/'
 Plate numbers can be CSV-style lists (123-5,255-63,312,1142) and indicate the cardinality of the set (!)
 Sheet format can indicate whether a 6110e exists (15s 5t is the typical modern sheet size, all else is 'special', OLD issues have 100s, 50s, other formats (esp definitives)
 The bulletin number can be used to find the bulletin pic at https://www.bait-tov.com/store/products/bulXXX.jpg
 The leaflet number (info folder) can be used to find the leaflet pic (TBD - I'm sure they have plans, but not there yet)
 Sometimes this page also shows additional pics, but ignore the flags and banners (for now) - might want to add them to Joint displays later.
 
 For now, I want to just parse and return the line - Swift can do perhaps more efficiently what I need (maybe not tho, JS screams on Apple devices now!)
 Focus on finding the string - top of BODY element's innerHTML is my first thought, let's see
 */

var raw_text = window.document.body.innerText
var raw_html = window.document.body.innerHTML
var text = raw_text
var result = { "data": text, "dom": raw_html };
webkit.messageHandlers.getItemDetails.postMessage(result);

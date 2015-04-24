// For parsing any of the 28 Bait-tov.com's Product Details pages
// Basic structure is in nested tables contained within a frame with name = "ProdDetails"
// All tables are contained within a master anonymous table of one row and column
// The MASTER table is further divided into subtables as follows
//   HEADER (table within table)
//   NOTES (table with images and bulleted list items, including catalog names if catalog fields are present)
//   DATA1 - DATAn (tables of data of fixed length of 20 items (or less on last table), as many as needed)
//   FOOTER (table within table to show page number(s) at bottom)
// This means the page count should be 6 + data table count; the first 3 tables can be ignored, 4 is NOTES, 5 is first data, and N-1 and N are FOOTER tables
//
// The HEADER has images and text of the form "What can be purchased in our store from the category 'X'"
// The NOTES contains one row, with three cells; the first and last cell contain images, but the second contains bulleted list items (LI)
// The first row of the first DATA table contains the column design for the page
// This row has cells that fall into the following categories
//   Item Code (always present) - a short string of the form 6110s254A or similar
//   Description ( "   " ) - a description of possibly several lines, starting with a country flag image (ISRAEL if not Joint Issues)
//   Catalog (0, 1, or 2) - fields that contain catalog descriptors for the item row, if any
//   Price (1, 2, or 4) - fields that contain pricing info for up to 4 varieties of the item
//   Status (always present) - a short string describing item availability
//   Pic (always present) - either blank or an image anchor icon that will click to the picture display page associated with the item
// Then the table rows follow containing data items as described by the above headers (total number of rows should agree with category.items)
// This goes on until the FOOTER tables are encountered.

var tables = document.getElementsByTagName("TABLE");

var rowCounts = [];
var dataTableCount = 0;
var bulletedList = "";
var headers = []; // including expanded fields (BuyX, OldPriceX)
var headersInternal = []; // doesn't include expanded fields
var dataItemCount = 0;
var items = [];

function splitHTMLTags( text ) {
    // stolen from Javascript: The Definitive Guide (Flanagan), definition of String.split(), 5th ed. p.706
    return text.split(/(<[^>]*>)/);
}

function replaceHTMLTags( textArray, replacement ) {
    var output = [];
    for (var i=0; i<textArray.length; ++i) {
        if (textArray[i].substring(0,1) == "<") {
            output.push(replacement);
        } else {
            output.push(textArray[i]);
        }
    }
    return output;
}

function removeHTMLTags( text ) {
    var lines = splitHTMLTags(text);
    var blines = replaceHTMLTags( lines, "" );
    return blines.join("").replace(/&nbsp;/g, "").replace(/&amp;/g, "&");
}

function parseHeaders( row, usePriceAddedFields ) {
    // save the headers
    var output = [];
    var cells = row.cells;
    for (var j=0; j<cells.length; ++j) {
        var text = cells[j].innerHTML;
        var lines = splitHTMLTags(text);
        if (lines.length > 2) {
            // concatenate the 1st two lines, skipping the tag in between
            text = lines[0];
            var next = lines[2];
            // don't concatenate price lines, however
            if (next.substring(0,2) != "($") {
                text = text + next;
            }
        }
        var priceAdded = false;
        switch(text) {
            case "Item Code":
                text = "ItemCode";
                break;
            case "Price (FDC)":
                text = "PriceFDC";
                priceAdded = true;
                break;
            case "Price (Used)":
                text = "PriceUsed";
                priceAdded = true;
                break;
            case "Price (Other)":
                text = "PriceOther";
                priceAdded = true;
                break;
            case "Catalog#1":
                text = "Catalog1";
                break;
            case "Catalog#2":
                text = "Catalog2";
                break;
            case "Price":
                priceAdded = true;
                break;
        }
        output.push(text);
        if (priceAdded && usePriceAddedFields) {
            output.push(getBuyHeaderName(text));
            output.push(getOldPriceHeaderName(text));
        }
    }
    return output;
}

function parsePriceData( text ) {
    var lines = splitHTMLTags(text);
    for (var i=0; i<lines.length; ++i) {
        var line = lines[i];
        var previous = (i==0? "": lines[i-1]);
        var next = (i==lines.length-1? "": lines[i+1]);
        if (previous == "<STRIKE>" || previous == "<strike>") {
            if (next == "</STRIKE>" || next == "</strike>") {
                lines[i] = ""; // remove any old price data
            }
        }
        if (line == "BUY") {
            lines[i] = "";
        }
    }
    // then remove all the rest of the HTML tags
    var blines = replaceHTMLTags( lines, "" );
    return blines.join("");
}

function getBuyHeaderName( priceHeader ) {
    return priceHeader.replace(/Price/, "Buy");
}

function getOldPriceHeaderName( priceHeader ) {
    return "Old" + priceHeader;
}

function parseStatusData( text ) {
    var output = removeHTMLTags(text);
    return output;
}

function parsePicData( text ) {
    // Typical Pic = "<img src=\"../images/nil.gif\" height=\"1\" width=\"40\"><br><a href=\"#\" onclick=\"PRODPIC = open('pic.php?ID=6110e144B','PRODPIC','resizable=yes,scrollbars=yes,height=400,width=450'); PRODPIC.focus(); return false;\"><img src=\"../images/cam.gif\" border=\"0\"></a>";
    var matches = text.match(/\'pic[^\']*\'/);
    if (matches == null) return "";
    var output = matches[0].replace(/\'/g, "");
    return output;
}

function parseData( row, headers ) {
    // save the headers
    var output = {};
    //return output; // DEBUGGING
    var cells = row.cells;
    for (var j=0; j<cells.length; ++j) {
        var header = headers[j];
        var cell = cells[j];
        var text = cell.innerHTML;
        switch(header) {
            case "Price":
            case "PriceFDC":
            case "PriceUsed":
            case "PriceOther":
                // need to parse out any <STRIKE> item price and <A> buy anchor, remember what's left
                output[header] = parsePriceData(text);
                var buyHeader = getBuyHeaderName(header);
                var anchors = cell.getElementsByTagName("A");
                var anchor = anchors.length == 0 ? "" : anchors[0].href;
                var index = anchor.indexOf("cart");
                if (index >= 0) anchor = anchor.substring(index);
                output[buyHeader] = anchor;
                var oldHeader = getOldPriceHeaderName(header);
                var olds = cell.getElementsByTagName("STRIKE");
                output[oldHeader] = olds.length == 0? "": olds[0].innerHTML;
                break;
            case "ItemCode":
            case "Description":
            case "Catalog1":
            case "Catalog2":
                // these fields need to have HTML tags and certain items (nbsp) removed
                output[header] = removeHTMLTags(text);
                break;
            case "Status":
                // this needs to have special parsing to get the text out of embedded FONT objects etc
                output[header] = parseStatusData(text);
                break;
            case "Pic":
                // this needs to have special parsing to get the pic ID
                output[header] = parsePicData(text);
                break;
        }
    }
    return output;
}

for (var i=0; i<tables.length; ++i) {
    switch (i) {
        case 0:
            rowCounts.push("MASTER = " + tables[i].rows.length + "," + tables[i].rows[0].cells.length);
            break;
        case 1:
            rowCounts.push("HEADER1 = " + tables[i].rows.length + "," + tables[i].rows[0].cells.length);
            break;
        case 2:
            rowCounts.push("HEADER2 = " + tables[i].rows.length + "," + tables[i].rows[0].cells.length);
            break;
        case 3:
            rowCounts.push("NOTES = " + tables[i].rows.length + "," + tables[i].rows[0].cells.length);
            // get the bulleted item list
            var text = tables[i].rows[0].cells[1].innerHTML;
            // remove all the HTML tags, leaving lines separated by /n
            bulletedList = removeHTMLTags(text);
            break;
        case tables.length - 2:
            rowCounts.push("FOOTER1 = " + tables[i].rows.length + "," + tables[i].rows[0].cells.length);
            break;
        case tables.length - 1:
            rowCounts.push("FOOTER2 = " + tables[i].rows.length + "," + tables[i].rows[0].cells.length);
            break;
        default:
            var rows = tables[i].rows;
            rowCounts.push("DATA[" + (++dataTableCount) + "] = " + rows.length + "," + rows[0].cells.length);
            for (var j=0; j< rows.length; ++j) {
                if (dataTableCount == 1 && j == 0) {
                    // save the headers
                    headers = parseHeaders( rows[j], true ); // all the headers
                    headersInternal = parseHeaders( rows[j], false ); // skip the expanded hdrs
                } else {
                    // parse the data in this row and save the object to the data array
                    ++dataItemCount;
                    var item = parseData( rows[j], headersInternal );
                    items.push(item);
                }
            }
            break;
    }
}

var result = { "dataCount": (tables.length > 0? dataItemCount: -1), "notes": bulletedList, "headers": headers, "items": items };
webkit.messageHandlers.getItems.postMessage(result);


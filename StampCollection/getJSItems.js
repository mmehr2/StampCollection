// For parsing the only page of Judaica Sales of interest - Austria Tabs.
//
/*
 Basic structure is of one top table with id="Table_01".
 This table has several rows, the 1st 4 of which are not of interest, but the 5th one is.
 It has one single column that contains our data.
 Data and notes are all contained within tables within this single column.
 If we get the list of all table elements within, there are many interesting ones:
 Every table in this collection consists of a single row (inside a <tbody>) with different #s of columns.
 table[0], 1 column - contains NOTES1 (main notes paragraphs)
 table[1], 1 column - contains NOTES2 (aux notes paragraph)
 table[3], 5 columns- contains the HEADERS
 table[4-N],5 columns-contains DATA (one row each)
 table[N+1],5 columns-contains FOOTER (item count if we want it) and stops the processing
 The best way to distinguish the footer (final row of processing) from previous DATA is to note that the text in the first cell/column starts with "AUI".
 The five columns are:
  Item # - starts with AUInnn[.m] where the nnn are the main number and .m is an optional extra FDC item
  <ignored> - this column has pic links and no header
  Description - this is the description text of the item, sometimes in <I> tags (italics)
  Mint - this is the price of the mint item (or "N/A"), including a $, within an <A> buy item tag
  FDC - this is the price of the FDC item (or "N/A"), similarly
 The header column text is contained within a <STRONG> element
*/

var topTable = document.getElementById("Table_01");
var column1 = topTable.rows[4].cells[0]
var tables = column1.getElementsByTagName("TABLE");

var rowCounts = [];
var dataTableCount = 0;
var notes = "";
var headers = []; // skipping the column we want to ignore (second one)
var internalHeaders = []; // including all five columns
var dataItemCount = 0;
var items = [];

//// BASIC UTILITIES //////
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

///// PAGE UTILITIES
function parseFinalTable( row ) {
    if (row.cells.length != 5) {
        return true;
    } else {
        var cell = row.cells[0];
        var tags = splitHTMLTags( cell.innerHTML );
        if (tags.length > 0 && tags[0].substring(0,3).toUpperCase() != "AUI") {
            return true;
        }
    }
    return false
}

function parseHeaders( row ) {
    // save the headers (only 4 saved from 5 cells in row)
    var output = [];
    var cells = row.cells;
    for (var j=0; j<cells.length; ++j) {
        if (j == 1) {
            output.push("Pic") // place holder
        } else {
            var text = cells[j].innerHTML;
            var data = removeHTMLTags(text);
            // remove spaces from headers
            data = data.replace(/ /g,"");
            output.push(data);
        }
    }
    return output;
}

function parseNotes( row ) {
    // concatenate the text from all cells
    var output = "";
    var cells = row.cells; // actually only one, but this will also work
    for (var j=0; j<cells.length; ++j) {
        var text = cells[j].innerHTML;
        var data = removeHTMLTags(text);
        // need to replace runs of multiple spaces with a single space
        data = data.replace(/  +/g, " ");
        output += data;
    }
    return output;
}

function parsePicData( text ) {
    // Typical Pic =
    var matches = text.match(/\'austrian_pic[^\']*\'/);
    if (matches == null) return "";
    var output = matches[0].replace(/\'/g, "");
    return output;
}

function parseData( row, headers ) {
    // save the row data under properties named by the headers (skip second cell data)
    var output = {};
    var cells = row.cells;
    for (var j=0; j<cells.length; ++j) {
        var header = headers[j];
        var text = cells[j].innerHTML;
        var data = ""
        if (j == 1) {
            // pic field has special processing
            data = parsePicData(text)
        } else {
            // regular data field
            data = removeHTMLTags(text);
            // need to remove leading whitespace from the description column (j == 2)
            // prob okay to process all though
            data = data.replace(/^\s*(\S)/, "$1");
            // also need to remove leading $ from price data
            data = data.replace(/^\$/, "")
        }
        output[header] = data;
    }
    return output;
}

// MAIN LOOP
for (var i=0; i<tables.length; ++i) {
    switch (i) {
        case 0:
            rowCounts.push("NOTES1 = " + tables[i].rows.length + "," + tables[i].rows[0].cells.length);
            notes += parseNotes( tables[i].rows[0] )
            break;
        case 1:
            rowCounts.push("NOTES2 = " + tables[i].rows.length + "," + tables[i].rows[0].cells.length);
            notes += parseNotes( tables[i].rows[0] )
            break;
        default:
            var rows = tables[i].rows;
            var cells = rows[0].cells
            // else, we have data
            rowCounts.push("DATA[" + (++dataTableCount) + "] = " + rows.length + "," + rows[0].cells.length);
            for (var j=0; j< rows.length; ++j) {
                if (dataTableCount == 1 && j == 0) {
                    // save the headers
                    headers = parseHeaders( rows[j] );
                } else {
                    // datect the possible final table by its first cell
                    if (parseFinalTable( rows[j] )) {
                        // this is the final table - OPT parse the item count (not all that useful)
                        rowCounts.push("FOOTER = " + tables[i].rows.length + "," + tables[i].rows[0].cells.length);
                        break
                    }
                    // parse the data in this row and save the object to the data array
                    ++dataItemCount;
                    var item = parseData( rows[j], headers );
                    items.push(item);
                }
            }
            break;
    }
}

var result = { /*"rowCounts": rowCounts,*/ "dataCount": dataItemCount, "notes": notes, "headers": headers, "items": items };
webkit.messageHandlers.getJSItems.postMessage(result);

// For parsing Bait-tov.com's SubCategories page
// There are two TR elements that should be ignored (1st two), followed by the row, and then the actual categories
// The 1st is the "Browsing Category" line (with total item count - useful?
// The 2nd is the "Sub Categories" title line
// The 3rd (parseable) should show three headers, "#", "Name" and "Items" (2015 March)
// The 4th - Nth are the actual lines, with a category number, name, and item count
// Current structure tho is the # is the innerHTML of the 1st TD
//   The Name TD contains an A element with an HREF property that has the SubCat=# (important) and
//     its innerHTML has a <font> element whose innerHTML is the actual name
//   The Items value is the innerHTML of the 3rd TD

var categoryRows = document.getElementsByTagName("TR");
var indexOfHeaders = 2;

function parseRow( row ) {
    var data = []
    var nodes = row.cells; // these are the TDs of the TR
    for (var i=0; i<nodes.length; ++i) {
        data.push(nodes[i].innerHTML);
    }
    return data; // JS: Array of String; objc: NSArray of NSString
}

function sanitizeString( data ) {
    return data
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"")
    .replace(/&#039;/g, "'");
}

function parseCategory( cellWithAnchor ) {
    var anchors = cellWithAnchor.getElementsByTagName("A");
    if (anchors.length == 0) {
        return { href: "", categoryName: "" }; // cell doesn't have an anchor as a child
    }
    var data = {};
    var anchor = anchors[0]; // if more than one, pick the first
    var hrefstr = anchor.href; // of form "products.php?SubCat=N&Mark=&Page=1"
    data.href = hrefstr;
    
    var rowstr = anchor.innerHTML; // could be a <font> element, or just the text (OR ...!)
    var fontElements = anchor.getElementsByTagName("FONT");
    if (fontElements.length != 0) {
        // use the first one
        rowstr = fontElements[0].innerHTML;
    }
    rowstr = sanitizeString(rowstr);
    data.categoryName = rowstr;
    return data;
}

function parseCategoryRow( row, numcols ) {
    var data = {};
    data["raw"] = row.innerHTML; // debugging
    var cols = parseRow(row);
    data["data"] = cols;
    // create anchor property if we have the proper number of table cells
    var anchor = { href: "", categoryName: "" }; // empty anchor by default
    if (cols.length == numcols) {
        anchor = parseCategory( row.cells[1] );
    }
    data["anchor"] = anchor;
    return data;
}

function parseCategories( headers, categoryRows, ignoreFirst ) {
    // headers = parseRow(categoryRows[indexOfHeaders]);
    var output = [];
    for (var i = ignoreFirst; i < categoryRows.length; ++i) {
        var row =  categoryRows[i];
        var parsedRow = parseCategoryRow( row, headers.length );
        // create an Object to represent the row
        var data = {};
//        data.raw = parsedRow.raw;
        data[headers[0]] = parsedRow.data[0]; // # (int)
        data.href = parsedRow.anchor.href; // href has the SubCat=N (needed for extracting data)
        data[headers[1]] = parsedRow.anchor.categoryName; // Name (string)
        data[headers[2]] = parsedRow.data[2]; // Items (int)
        // save the row in the output array
        output.push(data);
    }
    return output; // JS: Array of Object; objc: NSArray of NSDictionary
}


// ignore the 1st two row elements, the table header list is in the 3rd one
var headers = parseRow( categoryRows[indexOfHeaders] ); // ["#", "Name", "Items"]
// the categories start with row element #4
var categories = parseCategories( headers, categoryRows, indexOfHeaders+1 )
var result = { "tableRows": categories, "tableCols": headers };
webkit.messageHandlers.getCategories.postMessage(result);

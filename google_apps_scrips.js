function doPost(e) {
  try {
    // Log the incoming request for debugging
    Logger.log('Received POST request');
    
    // Get the active spreadsheet and sheet
    var spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = spreadsheet.getActiveSheet();
    
    // Check if postData exists
    if (!e || !e.postData || !e.postData.contents) {
      Logger.log('No postData found');
      return ContentService.createTextOutput(JSON.stringify({
        'status': 'error',
        'message': 'No data received'
      })).setMimeType(ContentService.MimeType.JSON);
    }
    
    // Parse the JSON data from the request
    var data = JSON.parse(e.postData.contents);
    Logger.log('Parsed data: ' + JSON.stringify(data));
    
    var logs = data.logs;
    
    // Check if logs array exists and has data
    if (!logs || !Array.isArray(logs) || logs.length === 0) {
      Logger.log('No logs in data');
      return ContentService.createTextOutput(JSON.stringify({
        'status': 'error',
        'message': 'No logs provided or logs is not an array'
      })).setMimeType(ContentService.MimeType.JSON);
    }
    
    // Log the number of logs received
    Logger.log('Processing ' + logs.length + ' logs');
    
    // Iterate through each log and append to sheet
    var successCount = 0;
    logs.forEach(function(log, index) {
      try {
        var row = [
          (log.uid || '').toString(),
          (log.timestamp || '').toString(),
          (log.latitude !== null && log.latitude !== undefined) ? log.latitude.toString() : '',
          (log.longitude !== null && log.longitude !== undefined) ? log.longitude.toString() : '',
          (log.address || '').toString(),
          (log.city || '').toString(),
          (log.user_name || '').toString(),      
          (log.user_class || '').toString(),     
          (log.device_info || '').toString()     
        ];
        
        sheet.appendRow(row);
        successCount++;
        Logger.log('Added row ' + (index + 1) + ': ' + JSON.stringify(row));
      } catch (rowError) {
        Logger.log('Error adding row ' + (index + 1) + ': ' + rowError.toString());
      }
    });
    
    Logger.log('Successfully added ' + successCount + ' rows');
    
    // Return success response
    return ContentService.createTextOutput(JSON.stringify({
      'status': 'success',
      'message': 'Data saved successfully',
      'count': successCount,
      'total': logs.length
    })).setMimeType(ContentService.MimeType.JSON);
    
  } catch (error) {
    // Log the error
    Logger.log('Error in doPost: ' + error.toString());
    Logger.log('Error stack: ' + error.stack);
    
    // Return error response
    return ContentService.createTextOutput(JSON.stringify({
      'status': 'error',
      'message': error.toString(),
      'stack': error.stack
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

// Function to handle GET requests (for testing)
function doGet(e) {
  try {
    Logger.log('Received GET request');
    
    return ContentService.createTextOutput(JSON.stringify({
      'status': 'success',
      'message': 'NFC Field Logger Sync API is running',
      'version': '2.0',
      'timestamp': new Date().toISOString()
    })).setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      'status': 'error',
      'message': error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

// Helper function to initialize sheet with headers (run this once manually)
function initializeSheet() {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  
  // Check if headers already exist
  if (sheet.getRange(1, 1).getValue() !== '') {
    Logger.log('Sheet already has data. Skipping initialization.');
    return;
  }
  
  // Add headers 
  sheet.appendRow(['UID', 'Timestamp', 'Latitude', 'Longitude', 'Address', 'City', 'User Name', 'User Class', 'Device Info']);
  
  // Format headers
  var headerRange = sheet.getRange(1, 1, 1, 9);  // Updated to 9 columns
  headerRange.setFontWeight('bold');
  headerRange.setBackground('#4285f4');
  headerRange.setFontColor('#ffffff');
  
  Logger.log('Sheet initialized with 9-column headers');
}

// Helper function to update existing sheets with missing columns
function updateExistingSheet() {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  
  // Check current column count
  var lastColumn = sheet.getLastColumn();
  Logger.log('Current columns: ' + lastColumn);
  
  if (lastColumn < 9) {
    // Add missing headers
    var missingHeaders = [];
    if (lastColumn < 7) missingHeaders.push('User Name');
    if (lastColumn < 8) missingHeaders.push('User Class');
    if (lastColumn < 9) missingHeaders.push('Device Info');
    
    // Get the header row and add missing columns
    var headerRow = sheet.getRange(1, lastColumn + 1, 1, missingHeaders.length);
    headerRow.setValues([missingHeaders]);
    headerRow.setFontWeight('bold');
    headerRow.setBackground('#4285f4');
    headerRow.setFontColor('#ffffff');
    
    Logger.log('Added missing columns: ' + missingHeaders.join(', '));
  } else {
    Logger.log('Sheet already has all 9 columns');
  }
}
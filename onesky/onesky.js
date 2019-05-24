/*
 * Install modules (i.e. globally like following):
 * npm install --global --save onesky
 * npm install --global --save onesky-utils
 * npm install --global --save fs-extra
 */
 
 // -------------------------
 // Setup - CHANGE THIS TO YOUR NEEDS
 // -------------------------
 
 /*
 * File should look like this:
 * exports.oneskySecret = '<SECRET>';
 * exports.oneskyApiKey = '<API KEY>';
 * exports.oneskyKeepStrings = <TRUE||FALSE>;
 */
const oneskyKeys = require('./../private/onesky_keys');

// here we need to map some android language shortcuts with onesky shortcuts, as far as I know currently all the ones with a small 'r' after '-'
var languageMappings = {};
languageMappings['pt-rBR'] = 'pt-BR';
languageMappings['zh-rCN'] = 'zh-CN';

// -------------------------
// Program
// -------------------------

//  required plugins
var onesky = require('onesky-utils');
//var fs = require('fs');
var fs = require('fs-extra'); // drop in replacement for fs, must be installed though
 
// 1) Read onesky setup
var oneskySecret = oneskyKeys.oneskySecret;
var oneskyApiKey = oneskyKeys.oneskyApiKey;
var oneskyKeepStrings = oneskyKeys.oneskyKeepStrings;
 
// 2) Read parameters
var action = process.argv[2]; 									// 1: upload/download
var label = process.argv[3]; 									// 2: some label
var projectId = process.argv[4]; 								// 3: onesky project id
var localFilePath = process.argv[5]; 							// 4: full path of local file 
var oneskyFileName = process.argv[6]; 							// 5: name of onesky file
var language = getLanguage(process.argv[7], languageMappings); 	// 6: language shortcut
 
console.log('Params: ' + action + " | " + projectId + " | " + localFilePath + " | " + oneskyFileName + " | " + language);
 
 if (action === 'upload') 
 {
	 // define onesky options
	 var optionsUpload = {
		language: language,
		secret: oneskySecret,
		apiKey: oneskyApiKey,
		projectId: projectId,
		fileName: oneskyFileName,
		format: 'ANDROID_XML',
		content: fs.readFileSync(localFilePath, 'utf8'),
		keepStrings: oneskyKeepStrings
	};
	
	// upload file
	onesky.postFile(optionsUpload).then(function(content) {
		var json = JSON.parse(content);
		if (json.meta.status >= 200 && json.meta.status < 300) {
			console.log(label + ": " + localFilePath + " [" + language + " | " + oneskyFileName + "] successfully uploaded!");
		} else {
			console.log(label + ": " + localFilePath + " [" + language + " | " + oneskyFileName + "] - Erroneous response received: " + content);
		}
	}).catch(function(err) {
		console.log(label + ": " + localFilePath + " [" + language + " | " + oneskyFileName + "] - Error occurred: " + err);
	});
 }
 else if (action === 'download')
 {
	// define onesky options
	 var optionsDownload = {
		language: language,
		secret: oneskySecret,
		apiKey: oneskyApiKey,
		projectId: projectId,
		fileName: oneskyFileName
	};
	
	// download file
	var outFolder = localFilePath.substring(0, localFilePath.lastIndexOf("/") + 1);
	fs.ensureDirSync(outFolder);	
	onesky.getFile(optionsDownload).then(function(content) {
		fs.writeFile(localFilePath, content, {encoding: 'utf8', flag: 'w'}, function(err) {
			if(err) {
				console.log(label + ": " + localFilePath + " [" + language + " | " + oneskyFileName + "] - Error occurred: " + err);
			} else {
				console.log(label + ": " + localFilePath + " [" + language + " | " + oneskyFileName + "] successfully downloaded!");
			}
			
		}); 
	}).catch(function(error) {
	  console.log(error);
	});
 }
 else
 {
	console.log('Invalid action received: ' + action);
 }
 
 // -------------------------
 // functions
 // -------------------------
 
function getLanguage(lang, languageMappings) {
	if (lang in languageMappings) {
		return languageMappings[lang];
	}
	return lang
}
 
 // -------------------------
 // OLD
 // -------------------------
 
 // define onesky projects id and res folders which the script should check
//var projects = [
//	new ProjectFile('EverywhereLauncher', '261063', 'M:/dev/apps/EverywhereLauncher/app-resources/src/main/res/', 'strings.xml', 'everywherelauncher_strings.xml'),
//	new ProjectFile('CoSy', '261063', 'M:/dev/apps/CoSy/app/src/main/res/', 'strings.xml', 'cosy_strings.xml'),
//	new ProjectFile('CoSy - Facebook', '261063', 'M:/dev/apps/CoSy/app/src/facebook/res/', 'strings.xml', 'cosy_fb_strings.xml'),
//	new ProjectFile('CoSy - WhatsApp', '261063', 'M:/dev/apps/CoSy/app/src/whatsapp/res/', 'strings.xml', 'cosy_wa_strings.xml'),
//	new ProjectFile('BackupManager', '261063', 'M:/dev/libraries/backupManager/src/main/res/', 'strings.xml', 'backupmanager_strings.xml')
//;
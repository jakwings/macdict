#import <Foundation/Foundation.h>

/**
 * from:
 * http://nshipster.com/dictionary-services/
 * https://github.com/mattt/DictionaryKit
 */
extern DCSDictionaryRef DCSDictionaryCreate(CFURLRef url);
extern DCSDictionaryRef DCSRecordGetSubDictionary(CFTypeRef record);
extern CFDictionaryRef DCSCopyDefinitionMarkup(DCSDictionaryRef dictionary, CFStringRef record);
extern CFStringRef DCSDictionaryGetName(DCSDictionaryRef dictionary);
extern CFStringRef DCSDictionaryGetShortName(DCSDictionaryRef dictionary);
extern CFArrayRef DCSCopyAvailableDictionaries();
extern CFArrayRef DCSCopyRecordsForSearchString(DCSDictionaryRef dictionary, CFStringRef string, void *, void *);
extern CFStringRef DCSRecordCopyData(CFTypeRef record);
extern CFStringRef DCSRecordCopyDataURL(CFTypeRef record);
extern CFStringRef DCSRecordGetAnchor(CFTypeRef record);
extern CFStringRef DCSRecordGetAssociatedObj(CFTypeRef record);
extern CFStringRef DCSRecordGetHeadword(CFTypeRef record);
extern CFStringRef DCSRecordGetRawHeadword(CFTypeRef record);
extern CFStringRef DCSRecordGetString(CFTypeRef record);
extern CFStringRef DCSRecordGetTitle(CFTypeRef record);

void NSPrint(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *string = [[NSString alloc] initWithFormat: format arguments: args];
    va_end(args);
    fprintf(stdout, "%s\n", [string UTF8String]);
    [string release];
}

void NSPrintErr(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *string = [[NSString alloc] initWithFormat: format arguments: args];
    va_end(args);
    fprintf(stderr, "%s\n", [string UTF8String]);
    [string release];
}

NSString *gProgramName;
void showHelpInformation()
{
    NSPrint(@"Usage: %@ [-h] [-l] [-d <dictionary> <words>", gProgramName);
    NSPrint(@"  -h    Display this help message.");
    NSPrint(@"  -l    Show indexed list of names of all available dictionaries.");
    NSPrint(@"  -d    Specify dictionary indexes to search in, using ',' to separate them");
    NSPrint(@"        Use 'all' to select all available dictionaries.");
    NSPrint(@"        If no dictionary is specified, it will look up the word or phrase in all available and only return the first definition found.");
}

NSMapTable *availableDictionariesKeyedByName = nil;
NSArray *availableDictionariesArray;
int setupSystemInformation()
{
    availableDictionariesKeyedByName = [NSMapTable
        mapTableWithKeyOptions: NSPointerFunctionsCopyIn
        valueOptions: NSPointerFunctionsObjectPointerPersonality];
    NSSet *availableDictionaries = [(NSSet *)DCSCopyAvailableDictionaries() autorelease];
    NSMutableArray *arrM = [NSMutableArray array];
    for (id dictionary in availableDictionaries) {
        NSString *name = (NSString *)DCSDictionaryGetName((DCSDictionaryRef)dictionary);
        [availableDictionariesKeyedByName setObject: dictionary forKey: name];
	[arrM addObject:dictionary];
    }
    availableDictionariesArray = [arrM sortedArrayUsingComparator:^(id obj1, id obj2){
	NSString *str1 = (NSString *)DCSDictionaryGetName((DCSDictionaryRef)obj1);
	NSString *str2 = (NSString *)DCSDictionaryGetName((DCSDictionaryRef)obj2);
	return [str1 compare:str2];	   
    }];
    return 0;
}

void showDictionaryList()
{
    @autoreleasepool {
        //for (NSString *name in availableDictionariesKeyedByName) {
        //    NSPrint(@"%@", name);
        //}

	for(int i=0; i<availableDictionariesArray.count; i++){
	    NSPrint(@"%d) %@", i+1, (NSString *)DCSDictionaryGetName((DCSDictionaryRef)(availableDictionariesArray[i])));
	}
    }
}

bool gToSearchInAllDictionaries = false;
bool gToShowDictionaryList = false;
bool gToShowHelpInformation = false;

int ch;
char *acceptedArgs = "d:lh";
int setupParameters_mod(const int argc, char *const argv[], const NSMutableArray *words, const NSMutableSet *dicts)
{
    while((ch = getopt(argc, argv, acceptedArgs)) != -1){
        switch(ch){
            case 'h':
                gToShowHelpInformation = true;
                return 0;
            case 'd':
                    if(strcmp(optarg, "all") != 0){
                        NSString *dictName = nil;
			const int len = strlen(optarg);
			char buffer[len+1];
		       	strcpy(buffer, optarg);
			char *p = strtok(buffer, ",");
			while(p != NULL){
			    int index;
			    sscanf(p,"%d",&index);
			    dictName = (NSString *)DCSDictionaryGetName((DCSDictionaryRef)availableDictionariesArray[index-1]);
			    if(dictName){
			        [dicts addObject:dictName];
			    }
			    p = strtok(NULL, ",");
			}
                    }else{
                        gToSearchInAllDictionaries = true;
                    }
                break;
            case 'l':
                gToShowDictionaryList = true;
                return 0;
            case '?':
            default:
                exit(-1);
        }
    }
    
    //the last parameter is the searching word
    if(argv[optind] != NULL){
        NSString *param = [NSString stringWithCString:argv[optind] encoding:NSUTF8StringEncoding];
        [words addObject:param];
    }else{
        printf("Please provide a word for searching.\n");
        exit(-1);
    }
    return 0;
}

int setupParameters(const int argc, const char *argv[], const NSMutableArray *words, const NSMutableSet *dicts)
{
    @autoreleasepool {
        bool inOptions = false;
        for (int i = 1; i < argc; i++) {
            NSString *param = [NSString stringWithCString: argv[i] encoding: NSUTF8StringEncoding];
            if (inOptions) {
                if ([param characterAtIndex: 0] != '-') {
                    if (!gToSearchInAllDictionaries) {
                        if (![param isEqualToString: @"all"]) {
                            [dicts addObject: param];
                        } else {
                            gToSearchInAllDictionaries = true;
                        }
                    }
                    inOptions = false;
                } else {
                    NSPrintErr(@"ERROR:\nInvalid option value for %@: %@",
                        [NSString stringWithCString: argv[i-1] encoding: NSUTF8StringEncoding], param);
                    return -1;
                }
            } else {
                if ([param characterAtIndex: 0] != '-') {
                    [words addObject: param];
                } else {
                    if ([param isEqualToString: @"-d"]) {
                        inOptions = true;
                    } else if ([param isEqualToString: @"-l"]) {
                        gToShowDictionaryList = true;
                    } else if ([param isEqualToString: @"-h"]) {
                        gToShowHelpInformation = true;
                    } else {
                        NSPrintErr(@"ERROR:\nInvalid option: %@", param);
                        return -1;
                    }
                }
            }
        }
        if (inOptions) {
            NSPrintErr(@"ERROR:\nThe last option requires a value.");
            return -1;
        }
        if (!gToShowDictionaryList && !gToShowHelpInformation && [words count] < 1) {
            NSPrintErr(@"ERROR:\nPlease provide words for searching.");
            return -1;
        }
    }
    return 0;
}

int searchDictionary(const NSString *phrase, const NSMutableSet *dicts)
{
    @autoreleasepool {
        if (!gToSearchInAllDictionaries && ([dicts count] == 0)) {
            DCSDictionaryRef dictionary = NULL;
            CFRange range = DCSGetTermRangeInString(dictionary, (CFStringRef)phrase, 0);
            CFStringRef definition = DCSCopyTextDefinition(dictionary, (CFStringRef)phrase, range);
            if (definition) {
                NSPrint(@"Definitions of <%@>\n%@", phrase, (NSString *)definition);
	    	CFRelease(definition);
            } else {
                NSPrint(@"Definitions of <%@>\n%@", phrase, @"(none)");
            }
        } else {
            int totalDefinitions = 0;
            for (id dictionaryName in (gToSearchInAllDictionaries ? availableDictionariesKeyedByName : dicts)) {
                DCSDictionaryRef dictionary = (DCSDictionaryRef)[availableDictionariesKeyedByName objectForKey: dictionaryName];
                CFRange range = DCSGetTermRangeInString(dictionary, (CFStringRef)phrase, 0);
                CFStringRef definition = DCSCopyTextDefinition(dictionary, (CFStringRef)phrase, range);
                if (range.location == kCFNotFound) {
                    continue;
                }
                CFStringRef term = (CFStringRef)[phrase substringWithRange: NSMakeRange(range.location, range.length)];

                if (definition) {
                    if (totalDefinitions > 0) {
                        NSPrint(@"\n");
                    }
                    NSPrint(@"Definitions of <%@> in {%@}\n%@", (NSString *)term, dictionaryName, (NSString *)definition);
                    totalDefinitions++;
		    CFRelease(definition);
                }

                /*// alternate mode?
                 *NSArray *records = (NSArray *)DCSCopyRecordsForSearchString(dictionary, term, NULL, NULL);
                 *if (records) {
                 *    for (id record in records) {
                 *        CFStringRef headword = DCSRecordGetHeadword((CFTypeRef)record);
                 *        if (headword) {
                 *            CFRange range = DCSGetTermRangeInString(dictionary, headword, 0);
                 *            CFStringRef definition = DCSCopyTextDefinition(dictionary, headword, range);
                 *            if (definition) {
                 *                if (totalDefinitions > 0) {
                 *                    NSPrint(@"\n");
                 *                }
                 *                NSPrint(@"Definitions of <%@> in {%@}\n%@", (NSString *)headword, dictionaryName, (NSString *)definition);
                 *                totalDefinitions++;
                 *            }
                 *        }
                 *    }
                 *}
                 */
            }
            if (totalDefinitions < 1) {
		    if(!gToSearchInAllDictionaries){
			    NSPrint(@"Definitions of <%@> in {%@}\n%@", phrase, [[dicts allObjects] componentsJoinedByString:@""], @"(none)");
		    }else{
                	NSPrint(@"Definitions of <%@> in {all}\n%@", phrase, @"(none)");
		    }
            }
        }
    }
    return 0;
}

int main(int argc, char *argv[])
{
    gProgramName = [NSString stringWithCString: argv[0] encoding: NSUTF8StringEncoding];
    if (argc < 2) {
        showHelpInformation();
        exit(-1);
    }
    NSMutableArray *words = [NSMutableArray array];
    NSMutableSet *dicts = [NSMutableSet set];
    int exitCode = 0;
    if ((exitCode = setupSystemInformation())) {
      exit(exitCode);
    }
    if ((exitCode = setupParameters_mod(argc, (void *)argv, words, dicts))) {
      exit(exitCode);
    }
    if (gToShowHelpInformation) {
        showHelpInformation();
        exit(0);
    }
    if (gToShowDictionaryList) {
        showDictionaryList();
        exit(0);
    }
    NSString *phrase = [words componentsJoinedByString: @" "];
    if ((exitCode = searchDictionary(phrase, dicts))) {
        exit(exitCode);
    }
    exit(0);
}

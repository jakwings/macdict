#import <Foundation/Foundation.h>

/**
 * References:
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
    NSPrint(@"Usage: %@ [-h] [-l] [-d <dictionary name>]... [-i <dictionary indexes>]... [word]...", gProgramName);
    NSPrint(@"  -h    Display this help message.");
    NSPrint(@"  -l    Show indexed list of names of all available dictionaries.");
    NSPrint(@"  -d    Specify a dictionary to search in.");
    NSPrint(@"        Use 'all' to select all available dictionaries.");
    NSPrint(@"        If no dictionary is specified, it will look up the word or phrase in all available dictionaries and only return the first definition found.");
    NSPrint(@"  -i    Specify dictionary indexes to search in, using ',' as delimiters.");
    NSPrint(@"        If indexes contain 0 then all available dictionaries are selected.");
}

NSMapTable *gAvailableDictionariesKeyedByName = NULL;
NSArray *gAvailableDictionariesKeyedByIndex = NULL;

int setupSystemInformation()
{
    gAvailableDictionariesKeyedByName = [NSMapTable
        mapTableWithKeyOptions: NSPointerFunctionsCopyIn
        valueOptions: NSPointerFunctionsObjectPointerPersonality];
    NSMutableArray *availableDictionaryArray = [[NSMutableArray array] autorelease];
    NSSet *availableDictionarySet = [(NSSet *)DCSCopyAvailableDictionaries() autorelease];
    for (id dictionary in availableDictionarySet) {
        NSString *name = (NSString *)DCSDictionaryGetName((DCSDictionaryRef)dictionary);
        [gAvailableDictionariesKeyedByName setObject: dictionary forKey: name];
        [availableDictionaryArray addObject: dictionary];
    }
    gAvailableDictionariesKeyedByIndex = [availableDictionaryArray sortedArrayUsingComparator: ^(id obj1, id obj2) {
        NSString *str1 = (NSString *)DCSDictionaryGetName((DCSDictionaryRef)obj1);
        NSString *str2 = (NSString *)DCSDictionaryGetName((DCSDictionaryRef)obj2);
        return [str1 compare: str2];	   
    }];
    return 0;
}

void showDictionaryList()
{
    for (int i = 0; i < gAvailableDictionariesKeyedByIndex.count; i++) {
        DCSDictionaryRef dictionary = (DCSDictionaryRef)gAvailableDictionariesKeyedByIndex[i];
        NSPrint(@"[%d] %@", i + 1, (NSString *)DCSDictionaryGetName(dictionary));
    }
}

bool gToSearchInAllDictionaries = false;
bool gToShowDictionaryList = false;
bool gToShowHelpInformation = false;

int setupParameters(const int argc, char *const argv[], const NSMutableArray *words, const NSMutableSet *dicts)
{
    NSString *param = NULL;
    NSString *indexes = NULL;
    char *acceptedArgs = "+d:i:lh";
    int i, ch;
    while ((ch = getopt(argc, argv, acceptedArgs)) != -1) {
        switch (ch) {
            case 'h':
                gToShowHelpInformation = true;
                return 0;
            case 'l':
                gToShowDictionaryList = true;
                return 0;
            case 'd':
                if (!gToSearchInAllDictionaries) {
                    param = [NSString stringWithCString: optarg encoding: NSUTF8StringEncoding];
                    if ([param isEqualToString: @"all"]) {
                        gToSearchInAllDictionaries = true;
                        [dicts removeAllObjects];
                        break;
                    }
                    if ([gAvailableDictionariesKeyedByName objectForKey: param]) {
                        [dicts addObject: param];
                    }
                }
                break;
            case 'i':
                if (!gToSearchInAllDictionaries) {
                    indexes = [NSString stringWithCString: optarg encoding: NSUTF8StringEncoding];
                    for (NSString *index in [indexes componentsSeparatedByString: @","]) {
                        if (index.intValue == 0) {
                            gToSearchInAllDictionaries = true;
                            [dicts removeAllObjects];
                            break;
                        }
                        param = (NSString *)DCSDictionaryGetName((DCSDictionaryRef)gAvailableDictionariesKeyedByIndex[index.intValue-1]);
                        if (param) {
                            [dicts addObject: param];
                        }
                    }
                }
                break;
            case '?':
            default:
                return -1;
        }
    }
    
    //the rest parameters are the searching words
    if (argv[optind] != NULL) {
        for (i = optind; argv[i] != NULL; i++) {
            [words addObject: [NSString stringWithCString: argv[i] encoding: NSUTF8StringEncoding]];
        }
    } else {
        if (!(gToShowHelpInformation || gToShowDictionaryList)) {
            NSPrintErr(@"Error:\n  Please provide a word for searching.");
            return -1;
        }
    }
    return 0;
}

int searchDictionary(const NSString *phrase, const NSMutableSet *dicts)
{
    if (!gToSearchInAllDictionaries && (dicts.count < 1)) {
        CFRange range = DCSGetTermRangeInString(NULL, (CFStringRef)phrase, 0);
        CFStringRef definition = DCSCopyTextDefinition(NULL, (CFStringRef)phrase, range);
        if (definition) {
            NSPrint(@"Definitions of <%@>\n\n%@", phrase, (NSString *)definition);
            CFRelease(definition);
        } else {
            NSPrint(@"Definitions of <%@>\n\n%@", phrase, @"(none)");
        }
    } else {
        int totalDefinitions = 0;
        for (id dictionaryName in (gToSearchInAllDictionaries ? gAvailableDictionariesKeyedByName : dicts)) {
            DCSDictionaryRef dictionary = (DCSDictionaryRef)[gAvailableDictionariesKeyedByName objectForKey: dictionaryName];
            CFRange range = DCSGetTermRangeInString(dictionary, (CFStringRef)phrase, 0);
            CFStringRef definition = DCSCopyTextDefinition(dictionary, (CFStringRef)phrase, range);
            if (range.location == kCFNotFound) {
                continue;
            }
            CFStringRef term = (CFStringRef)[phrase substringWithRange: NSMakeRange(range.location, range.length)];

            if (definition) {
                if (totalDefinitions > 0) {
                    NSPrint(@"%%");
                }
                NSPrint(@"Definitions of <%@> in {%@}\n\n%@", (NSString *)term, dictionaryName, (NSString *)definition);
                totalDefinitions++;
                CFRelease(definition);
            }
        }
        if (totalDefinitions < 1) {
            NSPrint(@"Definitions of <%@>\n\n%@", phrase, @"(none)");
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
    NSMutableArray *words = [[NSMutableArray array] autorelease];
    NSMutableSet *dicts = [[NSMutableSet set] autorelease];
    int exitCode = 0;
    if ((exitCode = setupSystemInformation())) {
        exit(exitCode);
    }
    if ((exitCode = setupParameters(argc, (void *)argv, words, dicts))) {
        showHelpInformation();
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

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
}

void NSPrintErr(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *string = [[NSString alloc] initWithFormat: format arguments: args];
    va_end(args);
    fprintf(stderr, "%s\n", [string UTF8String]);
}

NSString *gProgramName;
void showHelpInformation(bool toStderr)
{
    void (*print)(NSString *, ...) = toStderr ? NSPrintErr : NSPrint;
    print(@"Usage: %@ [-h] [-l] [-d <dictionary name>]... [-i <dictionary indexes>]... [word]...", gProgramName);
    print(@"  -h    Display this help message.");
    print(@"  -l    Show indexed list of names of all available dictionaries.");
    print(@"  -d    Specify a dictionary to search in.");
    print(@"        Use 'all' to select all available dictionaries.");
    print(@"        If no dictionary is specified, it will look up the word or phrase in all available dictionaries and only return the first definition found.");
    print(@"  -i    Specify dictionary indexes to search in, using ',' as delimiters.");
    print(@"        If indexes contain 0 then all available dictionaries are selected.");
    print(@"  -r    Show data in the XML format.");
}

NSMapTable *gAvailableDictionariesKeyedByName = NULL;
NSArray *gAvailableDictionariesKeyedByIndex = NULL;

int setupSystemInformation()
{
    gAvailableDictionariesKeyedByName = [NSMapTable
        mapTableWithKeyOptions: NSPointerFunctionsCopyIn
        valueOptions: NSPointerFunctionsObjectPointerPersonality];
    NSMutableArray *collectedDictionaries = [NSMutableArray array];
    NSArray *availableDictionaries = (__bridge_transfer NSArray *)DCSCopyAvailableDictionaries();
    for (id dictionary in availableDictionaries) {
        NSString *name = (__bridge NSString *)DCSDictionaryGetName((__bridge DCSDictionaryRef)dictionary);
        [gAvailableDictionariesKeyedByName setObject: dictionary forKey: name];
        [collectedDictionaries addObject: dictionary];
    }
    gAvailableDictionariesKeyedByIndex = [collectedDictionaries sortedArrayUsingComparator: ^(id obj1, id obj2) {
        NSString *str1 = (__bridge NSString *)DCSDictionaryGetName((__bridge DCSDictionaryRef)obj1);
        NSString *str2 = (__bridge NSString *)DCSDictionaryGetName((__bridge DCSDictionaryRef)obj2);
        return [str1 compare: str2];
    }];
    return 0;
}

void showDictionaryList()
{
    for (int i = 0; i < gAvailableDictionariesKeyedByIndex.count; i++) {
        DCSDictionaryRef dictionary = (__bridge DCSDictionaryRef)gAvailableDictionariesKeyedByIndex[i];
        NSPrint(@"[%d]\t%@", i + 1, (__bridge NSString *)DCSDictionaryGetName(dictionary));
    }
}

bool gToSearchInAllDictionaries = false;
bool gToShowDictionaryList = false;
bool gToShowHelpInformation = false;
bool gToShowRawData = false;

int setupParameters(const int argc, char *const argv[], const NSMutableArray *words, const NSMutableSet *dicts)
{
    NSString *param = NULL;
    NSString *indexes = NULL;
    char *acceptedArgs = "+d:i:rlh";
    int i, ch;
    while ((ch = getopt(argc, argv, acceptedArgs)) != -1) {
        switch (ch) {
            case 'h':
                gToShowHelpInformation = true;
                return 0;
            case 'l':
                gToShowDictionaryList = true;
                return 0;
            case 'r':
                gToShowRawData = true;
                break;
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
                        DCSDictionaryRef dictionary = (__bridge DCSDictionaryRef)gAvailableDictionariesKeyedByIndex[index.intValue-1];
                        param = (__bridge NSString *)DCSDictionaryGetName(dictionary);
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
    int totalDefinitions = 0;

    if (!gToSearchInAllDictionaries && (dicts.count < 1)) {
        CFRange range = DCSGetTermRangeInString(NULL, (__bridge CFStringRef)phrase, 0);
        if (range.location != kCFNotFound) {
            CFStringRef definition = DCSCopyTextDefinition(NULL, (__bridge CFStringRef)phrase, range);
            CFStringRef term = (__bridge_retained CFStringRef)[phrase substringWithRange: NSMakeRange(range.location, range.length)];

            NSMutableString *txt = [[NSMutableString alloc] initWithCapacity:0];
            NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\s+" options:0 error:nil];
            [txt setString:(__bridge NSString *)definition];
            if (!gToShowRawData) {
                [re replaceMatchesInString:txt options:0 range:NSMakeRange(0, [txt length]) withTemplate:@" "];
                [txt setString:[txt stringByTrimmingCharactersInSet:[NSMutableCharacterSet whitespaceAndNewlineCharacterSet]]];
            }
            NSPrint(@"Definitions of \"%@\":\n%@", (__bridge NSString *)term, txt);

            CFRelease(definition);
            CFRelease(term);
            totalDefinitions++;
        } else {
            NSPrintErr(@"Definitions of \"%@\":\n%@", phrase, @"(none)");
        }
    } else {
        for (id dictionaryName in (gToSearchInAllDictionaries ? gAvailableDictionariesKeyedByName : dicts)) {
            DCSDictionaryRef dictionary = (__bridge DCSDictionaryRef)[gAvailableDictionariesKeyedByName objectForKey: dictionaryName];

            // NEW!!!!!!!!!!!!
            NSArray *records = (__bridge_transfer NSArray *)DCSCopyRecordsForSearchString(dictionary, (__bridge CFStringRef)phrase, NULL, NULL);
            NSMutableString *txt = [[NSMutableString alloc] initWithCapacity:0];
            NSString *xsl = @"<?xml version='1.0' encoding='UTF-8'?>\
                            <xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'>\
                                <xsl:output method='text' encoding='UTF-8' indent='no'/>\
                                    <xsl:template match='/'>\
                                        <xsl:value-of select='normalize-space()'/>\
                                    </xsl:template>\
                            </xsl:stylesheet>\
                            ";
            for (id record in records) {
                CFStringRef definition = DCSRecordCopyData((__bridge CFTypeRef)record);
                CFStringRef term = DCSRecordGetHeadword((__bridge_retained CFTypeRef)record);

                [txt setString:(__bridge NSString *)definition];
                if (!gToShowRawData) {
                    NSXMLDocument *xml = [[NSXMLDocument alloc] initWithData:[txt dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                    NSData *data = [xml objectByApplyingXSLTString:xsl arguments:nil error:nil];
                    [txt setString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
                }
                if (totalDefinitions > 0) {
                    NSPrint(@"%%");
                }
                NSPrint(@"Definitions of \"%@\" in %@:\n%@", (__bridge NSString *)term, dictionaryName, txt);

                CFRelease(definition);
                CFRelease(term);
                totalDefinitions++;
            }
            continue;

            CFRange range = DCSGetTermRangeInString(dictionary, (__bridge CFStringRef)phrase, 0);
            if (totalDefinitions > 0) {
                if (range.location != kCFNotFound) {
                    NSPrint(@"%%");
                } else {
                    NSPrintErr(@"%%");
                }
            }
            if (range.location != kCFNotFound) {
                CFStringRef definition = DCSCopyTextDefinition(dictionary, (__bridge CFStringRef)phrase, range);
                CFStringRef term = (CFStringRef)CFBridgingRetain([phrase substringWithRange: NSMakeRange(range.location, range.length)]);
                NSPrint(@"Definitions of \"%@\" in %@:\n%@", (__bridge NSString *)term, dictionaryName, (__bridge NSString *)definition);
                CFRelease(definition);
                CFRelease(term);
                totalDefinitions++;
            } else {
                NSPrintErr(@"Definitions of \"%@\" in %@:\n(none)", phrase, dictionaryName);
            }
        }
    }
    return totalDefinitions > 0 ? 0 : 1;
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        gProgramName = [NSString stringWithCString: argv[0] encoding: NSUTF8StringEncoding];
        if (argc < 2) {
            showHelpInformation(false);
            return 0;
        }
        NSMutableArray *words = [NSMutableArray array];
        NSMutableSet *dicts = [NSMutableSet set];
        int exitCode = 0;
        if ((exitCode = setupSystemInformation())) {
            return exitCode;
        }
        if ((exitCode = setupParameters(argc, (void *)argv, words, dicts))) {
            NSPrintErr(@"");
            showHelpInformation(true);
            return exitCode;
        }
        if (gToShowHelpInformation) {
            showHelpInformation(false);
            return 0;
        }
        if (gToShowDictionaryList) {
            showDictionaryList();
            return 0;
        }
        NSString *phrase = [words componentsJoinedByString: @" "];
        if ((exitCode = searchDictionary(phrase, dicts))) {
            return exitCode;
        }
    }
    return 0;
}

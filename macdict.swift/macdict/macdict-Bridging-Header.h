//
//  macdict-Bridging-Header.h
//  macdict
//
//  Created by Jak Wings on 2014-10-26.
//
//

#ifndef macdict_macdict_Bridging_Header_h
#define macdict_macdict_Bridging_Header_h

#import <Foundation/Foundation.h>
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

#endif

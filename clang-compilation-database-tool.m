#import <Foundation/Foundation.h>
#include <libgen.h>

static void
CreateCompilationDBForSingleUnit(NSString *inputFile, NSString *outputFile, NSArray *command)
{
    NSDictionary *payload = @{
        @"directory":@(getwd(NULL)),
          @"command":[command componentsJoinedByString:@" "],
             @"file":inputFile
    };

    NSString *file = [[outputFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"compilation-db-unit"];
    [payload writeToFile:file atomically:NO];
}

static void
CreateCollectionDB(NSString *buildDir)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:[NSURL fileURLWithPath:buildDir]
                                          includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                                             options:NSDirectoryEnumerationSkipsHiddenFiles
                                                        errorHandler:^BOOL(NSURL *URL, NSError *error) {
        if (error) {
            fprintf(stderr, "Unable to enumerate path `%s': %s\n",
                            URL.path.UTF8String, error.localizedDescription.UTF8String);
        }
        return YES;
    }];

    NSMutableArray *units = [NSMutableArray new];
    for (NSURL *fileURL in enumerator) {
        NSNumber *isDirectory;
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if (!isDirectory.boolValue) {
            NSString *filename;
            [fileURL getResourceValue:&filename forKey:NSURLNameKey error:nil];
            if ([filename.pathExtension isEqualToString:@"compilation-db-unit"]) {
                [units addObject:[NSDictionary dictionaryWithContentsOfURL:fileURL]];
            }
        }
    }

    NSOutputStream *stream = [[NSOutputStream alloc] initToFileAtPath:@"/dev/stdout" append:YES];
    [stream open];
    NSError *error = nil;
    [NSJSONSerialization writeJSONObject:units toStream:stream options:NSJSONWritingPrettyPrinted error:&error];
    if (error) {
        fprintf(stderr, "Unable to serialize compilation units: %s\n", error.localizedDescription.UTF8String);
    }
    [stream close];
}

static NSString *
ExpandPath(NSString *path)
{
    NSURL *expandedURL = [[[NSURL fileURLWithPath:path] absoluteURL] URLByStandardizingPath];
    NSError *error = nil;
    if (![expandedURL checkResourceIsReachableAndReturnError:&error]) {
        fprintf(stderr, "%s\n", error.localizedDescription.UTF8String);
        return nil;
    }
    return expandedURL.path;
}

static int
ShowCommandForFile(NSString *compilationDatabaseFilename, NSString *sourceFilename)
{
    NSString *compilationDatabasePath = ExpandPath(compilationDatabaseFilename);
    NSString *sourcePath = ExpandPath(sourceFilename);
    NSString *command = nil;

    if (compilationDatabasePath && sourcePath) {
        NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:compilationDatabasePath];
        [stream open];
        NSError *error = nil;
        NSArray *commands = [NSJSONSerialization JSONObjectWithStream:stream options:0 error:&error];
        if (error) {
            fprintf(stderr, "Unable to de-serialize compilation DB: %s\n", error.localizedDescription.UTF8String);
        } else {
            for (NSDictionary *commandInfo in commands) {
                if ([commandInfo[@"file"] isEqualToString:sourcePath]) {
                    command = commandInfo[@"command"];
                    break;
                }
            }
        }
        [stream close];
    }

    if (command) {
        printf("%s\n", command.UTF8String);
        return 0;
    } else {
        fprintf(stderr, "Unable to locate command for source file at path `%s'\n", sourcePath.UTF8String);
        return 1;
    }
}

int
main(int argc, char **argv)
{
    if (argc > 5 && strncmp(argv[1], "dump", 4) == 0) {
        // Wow, amazing lazy hack! In the future, I should get real and use the ‘Clang Common Option Parser’.
        //
        // Specifically the expectation that `-c` is followed by the input file is completely based on Xcode just doing
        // it in that order atm.
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        NSString *outputFile = [ud stringForKey:@"o"];
        NSString *inputFile = [ud stringForKey:@"c"];
        if (outputFile && inputFile) {
            NSArray *arguments = [[NSProcessInfo processInfo] arguments];
            NSArray *command = [arguments subarrayWithRange:(NSRange){ 2, arguments.count-2 }];
            CreateCompilationDBForSingleUnit(inputFile, outputFile, command);
            return 0;
        }

    } else if (argc == 3 && strncmp(argv[1], "collect", 7) == 0) {
        CreateCollectionDB(@(argv[2]));
        return 0;
    } else if (argc == 4 && strncmp(argv[1], "command", 7) == 0) {
        return ShowCommandForFile(@(argv[2]), @(argv[3]));
    }

    char *tool = basename(argv[0]);
    fprintf(stderr, "Usage:\n" \
                    "\t$ %s dump [COMPILATION UNIT ARGUMENTS]\n" \
                    "\t$ %s collect path/to/DerivedData\n" \
                    "\t$ %s command path/to/compile_commands.json path/to/source_file\n",
                    tool, tool, tool);
    return 1;
}

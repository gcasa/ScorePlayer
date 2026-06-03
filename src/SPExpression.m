#import "SPExpression.h"

@interface SPExpression (Private)
+ (double)parseExpression:(const char **)cursor variables:(NSDictionary *)variables ok:(BOOL *)ok;
+ (double)parseTerm:(const char **)cursor variables:(NSDictionary *)variables ok:(BOOL *)ok;
+ (double)parseFactor:(const char **)cursor variables:(NSDictionary *)variables ok:(BOOL *)ok;
+ (void)skipSpace:(const char **)cursor;
@end

@implementation SPExpression

+ (double)evaluate:(NSString *)text variables:(NSDictionary *)variables ok:(BOOL *)ok
{
    const char *cursor;
    double value;

    if (ok != NULL)
        *ok = YES;
    if (text == nil)
        return 0.0;

    cursor = [text UTF8String];
    value = [self parseExpression:&cursor variables:variables ok:ok];
    return value;
}

+ (void)skipSpace:(const char **)cursor
{
    while (**cursor == ' ' || **cursor == '\t' || **cursor == '\n' || **cursor == '\r')
        (*cursor)++;
}

+ (double)parseExpression:(const char **)cursor variables:(NSDictionary *)variables ok:(BOOL *)ok
{
    double value;

    value = [self parseTerm:cursor variables:variables ok:ok];
    for (;;) {
        [self skipSpace:cursor];
        if (**cursor == '+') {
            (*cursor)++;
            value += [self parseTerm:cursor variables:variables ok:ok];
        } else if (**cursor == '-') {
            (*cursor)++;
            value -= [self parseTerm:cursor variables:variables ok:ok];
        } else {
            break;
        }
    }
    return value;
}

+ (double)parseTerm:(const char **)cursor variables:(NSDictionary *)variables ok:(BOOL *)ok
{
    double value;

    value = [self parseFactor:cursor variables:variables ok:ok];
    for (;;) {
        [self skipSpace:cursor];
        if (**cursor == '*') {
            (*cursor)++;
            value *= [self parseFactor:cursor variables:variables ok:ok];
        } else if (**cursor == '/') {
            double divisor;
            (*cursor)++;
            divisor = [self parseFactor:cursor variables:variables ok:ok];
            if (divisor != 0.0)
                value /= divisor;
        } else {
            break;
        }
    }
    return value;
}

+ (double)parseFactor:(const char **)cursor variables:(NSDictionary *)variables ok:(BOOL *)ok
{
    char *endPtr;
    const char *start;
    double sign;

    [self skipSpace:cursor];
    sign = 1.0;
    if (**cursor == '+') {
        (*cursor)++;
    } else if (**cursor == '-') {
        sign = -1.0;
        (*cursor)++;
    }

    [self skipSpace:cursor];
    if (**cursor == '(') {
        double value;
        (*cursor)++;
        value = [self parseExpression:cursor variables:variables ok:ok];
        [self skipSpace:cursor];
        if (**cursor == ')')
            (*cursor)++;
        return sign * value;
    }

    start = *cursor;
    if ((**cursor >= '0' && **cursor <= '9') || **cursor == '.') {
        double value;
        value = strtod(*cursor, &endPtr);
        *cursor = endPtr;
        return sign * value;
    }

    if ((**cursor >= 'A' && **cursor <= 'Z') || (**cursor >= 'a' && **cursor <= 'z') || **cursor == '_') {
        NSMutableString *name;
        NSNumber *number;

        name = [NSMutableString string];
        while ((**cursor >= 'A' && **cursor <= 'Z') ||
               (**cursor >= 'a' && **cursor <= 'z') ||
               (**cursor >= '0' && **cursor <= '9') ||
               **cursor == '_') {
            [name appendFormat:@"%c", **cursor];
            (*cursor)++;
        }
        number = [variables objectForKey:name];
        if (number != nil)
            return sign * [number doubleValue];
    }

    if (ok != NULL)
        *ok = NO;
    *cursor = start;
    return 0.0;
}

@end

// CustomFontHooks.xm

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>

// 插件配置键名
static NSString *const kCustomFontEnabledKey = @"com.wechat.enhance.customFont.enabled";
static NSString *const kCustomFontPathKey = @"com.wechat.enhance.customFont.path";
static NSString *const kCustomFontNameKey = @"com.wechat.enhance.customFont.name";

// 全局变量
static BOOL g_customFontEnabled = NO;
static BOOL g_fontLoaded = NO;
static NSString *g_customFontName = nil;
static NSString *g_customFontFamilyName = nil;
static CGFloat g_fontSizeOffset = 0.0;
static NSString *g_selectedFontPath = nil;
static BOOL g_isCreatingCustomFont = NO; // 添加递归保护标志

// 加载自定义字体
static BOOL loadCustomFont() {
    if (g_fontLoaded) {
        return YES;
    }
    
    // 从UserDefaults获取用户选择的字体路径
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *selectedFontPath = [defaults objectForKey:kCustomFontPathKey];
    NSString *selectedFontName = [defaults objectForKey:kCustomFontNameKey];
    
    // 如果控制器已经保存了字体路径，使用它
    NSString *fontPath = selectedFontPath;
    if (!fontPath) {
        // 如果没有设置，不再使用默认字体
        return NO;
    }
    
    g_selectedFontPath = fontPath;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:fontPath]) {
        // 字体文件不存在，直接返回
        return NO;
    }
    
    NSData *fontData = [NSData dataWithContentsOfFile:fontPath];
    if (!fontData) {
        return NO;
    }
    
    // 注册字体
    CFErrorRef error = NULL;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)fontData);
    CGFontRef font = CGFontCreateWithDataProvider(provider);
    BOOL success = CTFontManagerRegisterGraphicsFont(font, &error);
    
    if (!success) {
        if (error) CFRelease(error);
    } else {
        // 如果有用户选择的字体名称，直接使用
        if (selectedFontName) {
            g_customFontName = [selectedFontName copy];
        } else {
            // 获取注册后的字体名称和族名
            NSString *fontName = (__bridge_transfer NSString *)CGFontCopyPostScriptName(font);
            g_customFontName = [fontName copy];
        }
        
        // 创建临时字体对象获取更多信息
        CTFontRef tempFont = CTFontCreateWithGraphicsFont(font, 12.0, NULL, NULL);
        if (tempFont) {
            // 获取字体族名称
            g_customFontFamilyName = (__bridge_transfer NSString *)CTFontCopyFamilyName(tempFont);
            
            CFRelease(tempFont);
        }
        
        g_fontLoaded = YES;
    }
    
    // 释放资源
    if (font) CGFontRelease(font);
    if (provider) CGDataProviderRelease(provider);
    
    return success;
}

// 工具函数：加载设置
static void loadSettings() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    g_customFontEnabled = [defaults boolForKey:kCustomFontEnabledKey];
    g_selectedFontPath = [defaults objectForKey:kCustomFontPathKey];
}

// 创建自定义字体的统一方法，避免重复代码
static UIFont *createCustomFont(CGFloat size) {
    if (!g_customFontEnabled || !g_fontLoaded || !g_customFontName) {
        return nil;
    }
    
    // 尝试多种方式创建字体
    UIFont *customFont = nil;
    
    // 1. 使用保存的PostScript名称
    g_isCreatingCustomFont = YES; // 开始创建，设置标志位
    customFont = [UIFont fontWithName:g_customFontName size:size + g_fontSizeOffset];
    g_isCreatingCustomFont = NO; // 创建结束，重置标志位
    if (customFont) {
        return customFont;
    }
    
    // 2. 尝试使用字体族中的第一个字体
    if (g_customFontFamilyName) {
        g_isCreatingCustomFont = YES; // 开始创建，设置标志位
        NSArray *fontsInFamily = [UIFont fontNamesForFamilyName:g_customFontFamilyName];
        g_isCreatingCustomFont = NO; // 创建结束，重置标志位
        if (fontsInFamily.count > 0) {
            g_isCreatingCustomFont = YES; // 开始创建，设置标志位
            customFont = [UIFont fontWithName:fontsInFamily[0] size:size + g_fontSizeOffset];
            g_isCreatingCustomFont = NO; // 创建结束，重置标志位
            if (customFont) {
                return customFont;
            }
        }
    }
    
    // 3. 尝试使用字体文件名称作为字体名
    if (g_selectedFontPath) {
        NSString *fontFileName = [[g_selectedFontPath lastPathComponent] stringByDeletingPathExtension];
        g_isCreatingCustomFont = YES; // 开始创建，设置标志位
        customFont = [UIFont fontWithName:fontFileName size:size + g_fontSizeOffset];
        g_isCreatingCustomFont = NO; // 创建结束，重置标志位
        if (customFont) {
            return customFont;
        }
    }
    
    return nil;
}

%hook UIFont

+ (UIFont *)systemFontOfSize:(CGFloat)fontSize {
    if (g_customFontEnabled && !g_fontLoaded) {
        loadCustomFont();
    }
    
    UIFont *customFont = createCustomFont(fontSize);
    if (customFont) {
        return customFont;
    }
    
    id origFont = %orig;
    return origFont;
}

+ (UIFont *)systemFontOfSize:(CGFloat)fontSize weight:(CGFloat)weight {
    if (g_customFontEnabled && !g_fontLoaded) {
        loadCustomFont();
    }
    
    UIFont *customFont = createCustomFont(fontSize);
    if (customFont) {
        // 如果需要特定粗细，尝试设置
        if (weight != UIFontWeightRegular) {
            UIFontDescriptor *descriptor = [customFont.fontDescriptor fontDescriptorWithSymbolicTraits:
                (weight > UIFontWeightRegular) ? UIFontDescriptorTraitBold : 0];
            UIFont *weightedFont = [UIFont fontWithDescriptor:descriptor size:fontSize + g_fontSizeOffset];
            if (weightedFont) {
                return weightedFont;
            }
        }
        return customFont;
    }
    
    id origFont = %orig;
    return origFont;
}

// 捕获更多字体创建方法
+ (UIFont *)fontWithName:(NSString *)fontName size:(CGFloat)fontSize {
    // 检查是否正在创建自定义字体，防止递归
    if (g_isCreatingCustomFont) {
        return %orig;
    }
    
    if (g_customFontEnabled) { // 对总开关的判断
        if (!g_fontLoaded) {
            loadCustomFont();
        }
        
        UIFont *customFont = createCustomFont(fontSize);
        if (customFont) {
            return customFont;
        }
    }
    
    id origFont = %orig;
    return origFont;
}

%end

// 添加对TableView Header字体的hook
%hook UITableViewHeaderFooterView

- (void)setTextLabel:(UILabel *)textLabel {
    %orig;
    
    // 在setTextLabel之后修改字体
    if (g_customFontEnabled && !g_fontLoaded) {
        loadCustomFont();
    }
    
    if (g_customFontEnabled && g_fontLoaded && textLabel) {
        UIFont *originalFont = textLabel.font;
        if (originalFont) {
            UIFont *customFont = createCustomFont(originalFont.pointSize);
            if (customFont) {
                textLabel.font = customFont;
            }
        }
    }
}

- (void)layoutSubviews {
    %orig;
    
    // 在布局后再次尝试应用字体，确保不会被系统重置
    if (g_customFontEnabled && g_fontLoaded && self.textLabel) {
        UIFont *originalFont = self.textLabel.font;
        if (originalFont) {
            UIFont *customFont = createCustomFont(originalFont.pointSize);
            if (customFont) {
                self.textLabel.font = customFont;
            }
        }
    }
}

%end

// 添加对UITableView部分特殊字体设置方法的hook
%hook UITableView

// hook表头字体获取方法
- (UIFont *)_sectionHeaderTitleFont {
    if (g_customFontEnabled && !g_fontLoaded) {
        loadCustomFont();
    }
    
    UIFont *origFont = %orig;
    if (g_customFontEnabled && g_fontLoaded && origFont) {
        UIFont *customFont = createCustomFont(origFont.pointSize);
        if (customFont) {
            return customFont;
        }
    }
    
    return origFont;
}

// hook表尾字体获取方法
- (UIFont *)_sectionFooterTitleFont {
    if (g_customFontEnabled && !g_fontLoaded) {
        loadCustomFont();
    }
    
    UIFont *origFont = %orig;
    if (g_customFontEnabled && g_fontLoaded && origFont) {
        UIFont *customFont = createCustomFont(origFont.pointSize);
        if (customFont) {
            return customFont;
        }
    }
    
    return origFont;
}

%end

// 添加对UITableViewCell的hook
%hook UITableViewCell

- (void)setTextLabel:(UILabel *)textLabel {
    %orig;
    
    // 在设置textLabel后立即应用自定义字体
    if (g_customFontEnabled && !g_fontLoaded) {
        loadCustomFont();
    }
    
    if (g_customFontEnabled && g_fontLoaded && textLabel) {
        UIFont *originalFont = textLabel.font;
        if (originalFont) {
            UIFont *customFont = createCustomFont(originalFont.pointSize);
            if (customFont) {
                textLabel.font = customFont;
            }
        }
    }
}

- (void)setDetailTextLabel:(UILabel *)detailTextLabel {
    %orig;

    if (g_customFontEnabled && !g_fontLoaded) {
        loadCustomFont();
    }
    
    if (g_customFontEnabled && g_fontLoaded && detailTextLabel) {
        UIFont *originalFont = detailTextLabel.font;
        if (originalFont) {
            UIFont *customFont = createCustomFont(originalFont.pointSize);
            if (customFont) {
                detailTextLabel.font = customFont;
            }
        }
    }
}

- (void)layoutSubviews {
    %orig;
    
    // 在布局后再次尝试应用字体，确保不会被系统重置
    if (g_customFontEnabled && g_fontLoaded) {
        // 处理主标签
        if (self.textLabel) {
            UIFont *originalFont = self.textLabel.font;
            if (originalFont) {
                UIFont *customFont = createCustomFont(originalFont.pointSize);
                if (customFont) {
                    self.textLabel.font = customFont;
                }
            }
        }
        
        // 处理详情标签
        if (self.detailTextLabel) {
            UIFont *originalFont = self.detailTextLabel.font;
            if (originalFont) {
                UIFont *customFont = createCustomFont(originalFont.pointSize);
                if (customFont) {
                    self.detailTextLabel.font = customFont;
                }
            }
        }
    }
}

%end

// hook UILabel来捕获那些可能在其他hook之外设置字体的情况
%hook UILabel

- (void)setFont:(UIFont *)font {
    if (g_customFontEnabled && !g_fontLoaded) {
        loadCustomFont();
    }
    
    // 无条件替换字体
    if (g_customFontEnabled && g_fontLoaded && font) {
            UIFont *customFont = createCustomFont(font.pointSize);
            if (customFont) {
                %orig(customFont);
                return;
        }
    }
    
    %orig;
}

// 添加对初始化方法的hook
- (id)initWithFrame:(CGRect)frame {
    id orig = %orig;
    
    if (g_customFontEnabled && g_fontLoaded && orig) {
        UILabel *label = (UILabel *)orig;
        if (label.font) {
            UIFont *customFont = createCustomFont(label.font.pointSize);
            if (customFont) {
                label.font = customFont;
            }
        }
    }
    
    return orig;
}

// 处理可能在外部直接访问的字体属性
- (UIFont *)font {
    UIFont *originalFont = %orig;
    
    // 移除所有限制条件，无条件替换字体
    if (g_customFontEnabled && g_fontLoaded && originalFont) {
            UIFont *customFont = createCustomFont(originalFont.pointSize);
            if (customFont) {
                return customFont;
        }
    }
    
    return originalFont;
}

// 对 setAttributedText 的处理
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (g_customFontEnabled && !g_fontLoaded) {
        loadCustomFont();
    }
    
    if (g_customFontEnabled && g_fontLoaded && attributedText) {
        NSMutableAttributedString *mutableAttributedText = [attributedText mutableCopy];
        __block BOOL fontChanged = NO; 
        
        // 遍历属性字符串，查找并替换字体
        [mutableAttributedText enumerateAttribute:NSFontAttributeName 
                                          inRange:NSMakeRange(0, mutableAttributedText.length) 
                                          options:0 
                                       usingBlock:^(id value, NSRange range, BOOL *stop) {
            if (value && [value isKindOfClass:[UIFont class]]) {
                UIFont *originalFont = (UIFont *)value;
                UIFont *customFont = createCustomFont(originalFont.pointSize);
                if (customFont) {
                    [mutableAttributedText removeAttribute:NSFontAttributeName range:range];
                    [mutableAttributedText addAttribute:NSFontAttributeName value:customFont range:range];
                    fontChanged = YES;
                }
            }
        }];
        
        // 如果字体被修改，则调用原始方法传入修改后的字符串
        if (fontChanged) {
            %orig(mutableAttributedText);
            return;
        }
    }
    
    // 如果未启用或未找到字体，调用原始方法
    %orig;
}

%end

// 插件入口
%ctor {
    // 加载设置
    loadSettings();
    
    // 预加载字体
    if (g_customFontEnabled) {
        loadCustomFont();
    }
} 
#import "CSFontSettingsViewController.h"
#import <CoreText/CoreText.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

// UserDefaults Key常量
static NSString * const kCustomFontEnabledKey = @"com.wechat.enhance.customFont.enabled";
static NSString * const kCustomFontPathKey = @"com.wechat.enhance.customFont.path";
static NSString * const kCustomFontNameKey = @"com.wechat.enhance.customFont.name";

// 存储目录常量
static NSString * const kWechatEnhanceFolderName = @"WechatEnhance";

// 设置项类型枚举
typedef NS_ENUM(NSInteger, SettingItemType) {
    SettingItemTypeNormal,  
    SettingItemTypeSwitch,  
    SettingItemTypeAction   
};

// 设置项数据结构
@interface FontSettingItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *iconName;
@property (nonatomic, strong, nullable) UIColor *iconColor;
@property (nonatomic, copy, nullable) NSString *detail;
@property (nonatomic, assign) SettingItemType itemType;
@property (nonatomic, assign) BOOL switchValue;
@property (nonatomic, copy, nullable) void (^switchValueChanged)(BOOL isOn);
@property (nonatomic, copy, nullable) void (^actionBlock)(void);

+ (instancetype)itemWithTitle:(NSString *)title
                     iconName:(nullable NSString *)iconName
                    iconColor:(nullable UIColor *)iconColor
                       detail:(nullable NSString *)detail;

+ (instancetype)switchItemWithTitle:(NSString *)title
                           iconName:(nullable NSString *)iconName
                          iconColor:(nullable UIColor *)iconColor
                        switchValue:(BOOL)switchValue
                  valueChangedBlock:(nullable void(^)(BOOL isOn))valueChanged;

+ (instancetype)actionItemWithTitle:(NSString *)title
                           iconName:(nullable NSString *)iconName
                          iconColor:(nullable UIColor *)iconColor;
@end

@implementation FontSettingItem

+ (instancetype)itemWithTitle:(NSString *)title iconName:(NSString *)iconName iconColor:(UIColor *)iconColor detail:(NSString *)detail {
    FontSettingItem *item = [[FontSettingItem alloc] init];
    item.title = title;
    item.iconName = iconName;
    item.iconColor = iconColor;
    item.detail = detail;
    item.itemType = SettingItemTypeNormal;
    return item;
}

+ (instancetype)switchItemWithTitle:(NSString *)title iconName:(NSString *)iconName iconColor:(UIColor *)iconColor switchValue:(BOOL)switchValue valueChangedBlock:(void (^)(BOOL))valueChanged {
    FontSettingItem *item = [[FontSettingItem alloc] init];
    item.title = title;
    item.iconName = iconName;
    item.iconColor = iconColor;
    item.switchValue = switchValue;
    item.switchValueChanged = valueChanged;
    item.itemType = SettingItemTypeSwitch;
    return item;
}

+ (instancetype)actionItemWithTitle:(NSString *)title iconName:(NSString *)iconName iconColor:(UIColor *)iconColor {
    FontSettingItem *item = [[FontSettingItem alloc] init];
    item.title = title;
    item.iconName = iconName;
    item.iconColor = iconColor;
    item.itemType = SettingItemTypeAction;
    return item;
}

@end

// 设置分组数据结构
@interface FontSettingSection : NSObject
@property (nonatomic, copy) NSString *header;
@property (nonatomic, copy, nullable) NSString *footer;
@property (nonatomic, copy) NSArray<FontSettingItem *> *items;

+ (instancetype)sectionWithHeader:(NSString *)header items:(NSArray<FontSettingItem *> *)items;
@end

@implementation FontSettingSection

+ (instancetype)sectionWithHeader:(NSString *)header items:(NSArray<FontSettingItem *> *)items {
    FontSettingSection *section = [[FontSettingSection alloc] init];
    section.header = header;
    section.items = items;
    return section;
}

@end

@interface CSFontSettingsViewController () <UIDocumentPickerDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) NSArray<FontSettingSection *> *sections;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *fontsList;
@property (nonatomic, strong) NSString *selectedFontPath;
@property (nonatomic, strong) NSString *selectedFontName;
@property (nonatomic, strong) NSFileManager *fileManager;
@end

@implementation CSFontSettingsViewController

#pragma mark - 生命周期方法

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 初始化文件管理器
    self.fileManager = [NSFileManager defaultManager];
    
    // 设置标题
    self.title = @"字体设置";
    
    // 设置UI样式
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 54, 0, 0);
    
    // 注册标准单元格替代CSSettingTableViewCell
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"FontSettingCell"];
    // 使用带详情文本的单元格风格
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"FontSettingDetailCell"];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"FontSettingSwitchCell"];
    
    // 初始化字体列表
    self.fontsList = [NSMutableArray array];
    
    // 加载字体列表
    [self loadFontsList];
    
    // 设置数据
    [self setupData];
    
    // 确保目录存在
    [self ensureDirectoryExists:[self getWechatEnhancePath]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 每次页面显示时刷新字体列表
    [self loadFontsList];
    [self setupData];
    [self.tableView reloadData];
}

#pragma mark - 文件和目录管理方法

// 确保目录存在
- (BOOL)ensureDirectoryExists:(NSString *)path {
    if (!path) return NO;
    
    BOOL isDirectory = NO;
    BOOL exists = [self.fileManager fileExistsAtPath:path isDirectory:&isDirectory];
    
    if (exists && isDirectory) {
        return YES; // 目录已存在
    }
    
    if (exists && !isDirectory) {
        // 路径存在但不是目录，尝试删除
        NSError *removeError = nil;
        if (![self.fileManager removeItemAtPath:path error:&removeError]) {
            return NO; // 无法删除已存在的文件
        }
    }
    
    // 创建目录
    NSError *createError = nil;
    BOOL success = [self.fileManager createDirectoryAtPath:path 
                               withIntermediateDirectories:YES 
                                                attributes:nil 
                                                     error:&createError];
    return success;
}

// 获取增强功能目录路径
- (NSString *)getWechatEnhancePath {
    // 使用Library/Preferences目录
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *preferencesPath = [libraryPath stringByAppendingPathComponent:@"Preferences"];
    NSString *enhancePath = [preferencesPath stringByAppendingPathComponent:kWechatEnhanceFolderName];
    
    // 确保目录存在
    [self ensureDirectoryExists:enhancePath];
    
    return enhancePath;
}

#pragma mark - 数据加载方法

// 加载字体列表
- (void)loadFontsList {
    // 清空当前列表
    [self.fontsList removeAllObjects];
    
    // 获取增强功能目录中的所有字体文件
    NSString *enhancePath = [self getWechatEnhancePath];
    
    // 确保目录存在
    if (![self ensureDirectoryExists:enhancePath]) {
        return;
    }
    
    NSError *error = nil;
    NSArray *contents = [self.fileManager contentsOfDirectoryAtPath:enhancePath error:&error];
    
    if (error) {
        return;
    }
    
    // 过滤出字体文件
    NSArray *fontExtensions = @[@"ttf", @"otf"];
    for (NSString *filename in contents) {
        NSString *extension = [filename pathExtension].lowercaseString;
        if ([fontExtensions containsObject:extension]) {
            NSString *fontPath = [enhancePath stringByAppendingPathComponent:filename];
            
            // 获取字体文件信息
            NSDictionary *attributes = [self.fileManager attributesOfItemAtPath:fontPath error:&error];
            NSDate *modificationDate = error ? [NSDate date] : [attributes fileModificationDate];
            
            // 尝试获取字体名称
            NSString *fontName = [self getFontNameFromPath:fontPath];
            
            // 添加到字体列表
            [self.fontsList addObject:@{
                @"filename": filename,
                @"path": fontPath,
                @"date": modificationDate,
                @"fontName": fontName ?: @"未知字体"
            }];
        }
    }
    
    // 按修改日期排序，最新的在前面
    [self.fontsList sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        return [obj2[@"date"] compare:obj1[@"date"]];
    }];
    
    // 获取当前选择的字体
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.selectedFontPath = [defaults objectForKey:kCustomFontPathKey];
    self.selectedFontName = [defaults objectForKey:kCustomFontNameKey];
}

// 尝试从字体文件获取字体名称
- (NSString *)getFontNameFromPath:(NSString *)fontPath {
    if (!fontPath) return nil;
    
    NSData *fontData = [NSData dataWithContentsOfFile:fontPath];
    if (!fontData) {
        return nil;
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)fontData);
    if (!provider) {
        return nil;
    }
    
    CGFontRef font = CGFontCreateWithDataProvider(provider);
    
    if (!font) {
        CGDataProviderRelease(provider);
        return nil;
    }
    
    NSString *fontName = (__bridge_transfer NSString *)CGFontCopyPostScriptName(font);
    
    CGFontRelease(font);
    CGDataProviderRelease(provider);
    
    return fontName;
}

// 设置UI数据
- (void)setupData {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *allSections = [NSMutableArray array];
    
    // 1. 基本设置组
    BOOL fontEnabled = [defaults boolForKey:kCustomFontEnabledKey];
    
    FontSettingItem *enableItem = [FontSettingItem switchItemWithTitle:@"启用自定义字体" 
                                                          iconName:@"textformat" 
                                                         iconColor:[UIColor systemBlueColor] 
                                                       switchValue:fontEnabled
                                                 valueChangedBlock:^(BOOL isOn) {
        [defaults setBool:isOn forKey:kCustomFontEnabledKey];
        [defaults synchronize];
        // 重新设置数据（重建菜单）
        [self setupData];
        [self.tableView reloadData];
        
        // 只有在已选择字体的情况下，切换开关状态才需要重启
        if (self.selectedFontPath != nil) {
            [self showRestartAlert];
        }
    }];
    
    FontSettingSection *basicSection = [FontSettingSection sectionWithHeader:@"基本设置" 
                                                                  items:@[enableItem]];
    [allSections addObject:basicSection];
    
    // 只有启用自定义字体时才显示下面的区域
    if (fontEnabled) {
        // 2. 添加字体区域
        FontSettingItem *addFontItem = [FontSettingItem actionItemWithTitle:@"添加字体文件" 
                                                               iconName:@"plus.circle.fill" 
                                                              iconColor:[UIColor systemGreenColor]];
        addFontItem.actionBlock = ^{
            [self showDocumentPicker];
        };
        
        FontSettingSection *addFontSection = [FontSettingSection sectionWithHeader:@"添加字体" 
                                                                        items:@[addFontItem]];
        [allSections addObject:addFontSection];
        
        // 3. 字体列表区域
        if (self.fontsList.count > 0) {
            NSMutableArray *fontItems = [NSMutableArray array];
            
            for (NSDictionary *fontDict in self.fontsList) {
                NSString *fontPath = fontDict[@"path"];
                NSString *fontName = fontDict[@"fontName"];
                NSString *fileName = fontDict[@"filename"];
                
                // 检查是否为当前选中的字体
                BOOL isSelected = [fontPath isEqualToString:self.selectedFontPath];
                
                // 为每个字体创建一个设置项
                FontSettingItem *fontItem = [FontSettingItem itemWithTitle:fileName
                                                              iconName:@"textformat" 
                                                             iconColor:[UIColor systemIndigoColor]
                                                                detail:isSelected ? @"已选择" : nil];
                
                // 设置操作
                fontItem.actionBlock = ^{
                    [self selectFont:fontPath fontName:fontName];
                };
                
                [fontItems addObject:fontItem];
            }
            
            FontSettingSection *fontsSection = [FontSettingSection sectionWithHeader:@"已添加字体" 
                                                                         items:fontItems];
            [allSections addObject:fontsSection];
        }
    }
    
    // 4. 添加使用说明区域
    FontSettingItem *helpItem = [FontSettingItem itemWithTitle:@"使用说明"
                                                  iconName:@"info.circle" 
                                                 iconColor:[UIColor systemBlueColor]
                                                    detail:nil];
    
    helpItem.actionBlock = ^{
        [self showHelpGuide];
    };
    
    FontSettingSection *helpSection = [FontSettingSection sectionWithHeader:@"帮助" 
                                                                  items:@[helpItem]];
    [allSections addObject:helpSection];
    
    self.sections = [allSections copy];
}

#pragma mark - 事件处理方法

// 显示文档选择器
- (void)showDocumentPicker {
    // 使用更简单的方式定义文件类型
    NSArray *documentTypes = @[
        @"public.truetype-font",    // TTF
        @"public.opentype-font",    // OTF
        @"com.adobe.postscript-font"  // PS字体
    ];
    
    // 禁用弃用警告
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // 使用iOS 14以前的API创建文档选择器
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] 
                                                     initWithDocumentTypes:documentTypes 
                                                     inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
    
    documentPicker.delegate = self;
    documentPicker.allowsMultipleSelection = YES;
    
    [self presentViewController:documentPicker animated:YES completion:nil];
}

// 选择字体
- (void)selectFont:(NSString *)fontPath fontName:(NSString *)fontName {
    // 保存选择的字体
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:fontPath forKey:kCustomFontPathKey];
    [defaults setObject:fontName forKey:kCustomFontNameKey];
    [defaults synchronize];
    
    // 更新界面
    self.selectedFontPath = fontPath;
    self.selectedFontName = fontName;
    
    // 刷新数据
    [self setupData];
    [self.tableView reloadData];
    
    // 显示重启提示
    [self showRestartAlert];
}

// 删除字体
- (void)deleteFont:(NSString *)fontPath {
    BOOL needsRestart = NO;
    
    // 如果是当前选中的字体，清除选择并标记需要重启
    if ([fontPath isEqualToString:self.selectedFontPath]) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:kCustomFontPathKey];
        [defaults removeObjectForKey:kCustomFontNameKey];
        [defaults synchronize];
        
        self.selectedFontPath = nil;
        self.selectedFontName = nil;
        needsRestart = YES;
    }
    
    // 删除文件
    NSError *error = nil;
    if (![self.fileManager removeItemAtPath:fontPath error:&error]) {
        // 处理删除失败情况
        [self showErrorAlertWithTitle:@"删除失败" message:[NSString stringWithFormat:@"无法删除字体文件：%@", error.localizedDescription]];
        return;
    }
    
    // 刷新列表
    [self loadFontsList];
    [self setupData];
    [self.tableView reloadData];
    
    // 如果删除的是当前选中的字体，显示重启提示
    if (needsRestart) {
        [self showAlertWithTitle:@"已删除选中字体" 
                        message:@"您已删除当前使用的字体，将恢复使用系统默认字体，需要重启才能生效。"
                destructiveTitle:@"立即重启"
                    cancelTitle:@"稍后重启"
              destructiveAction:^{
                  exit(0); // 立即退出应用
              }];
    }
}

#pragma mark - 弹窗工具方法

// 通用弹窗方法
- (void)showAlertWithTitle:(NSString *)title 
                   message:(NSString *)message 
           destructiveTitle:(NSString *)destructiveTitle
               cancelTitle:(NSString *)cancelTitle
         destructiveAction:(void(^)(void))destructiveAction {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    if (destructiveTitle && destructiveAction) {
        [alert addAction:[UIAlertAction actionWithTitle:destructiveTitle 
                                               style:UIAlertActionStyleDestructive 
                                             handler:^(UIAlertAction * _Nonnull action) {
            if (destructiveAction) destructiveAction();
        }]];
    }
    
    if (cancelTitle) {
        [alert addAction:[UIAlertAction actionWithTitle:cancelTitle style:UIAlertActionStyleCancel handler:nil]];
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

// 错误提示
- (void)showErrorAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// 添加重启提示方法
- (void)showRestartAlert {
    [self showAlertWithTitle:@"需要重启" 
                   message:@"字体设置已更改，需要重启才能生效。"
           destructiveTitle:@"立即重启"
               cancelTitle:@"稍后重启"
         destructiveAction:^{
             exit(0); // 立即退出应用
         }];
}

// 添加使用说明弹窗方法
- (void)showHelpGuide {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"使用说明"
                                                                             message:@"• 点击字体项可选择该字体作为系统字体\n• 左滑字体项可删除该字体\n• 添加字体后需手动选择才会生效\n• 更改字体设置后需重启才能生效"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"我知道了" 
                                                        style:UIAlertActionStyleDefault 
                                                      handler:nil]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

// iOS 13及以上版本的代理方法
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    [self processSelectedFontFiles:urls];
}

// 处理用户取消文档选择器
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    // 可以添加用户反馈，如提示声或轻微振动
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [generator prepare];
    [generator impactOccurred];
}

// 处理选中的字体文件
- (void)processSelectedFontFiles:(NSArray<NSURL *> *)urls {
    if (urls.count == 0) {
        return;
    }
    
    // 显示加载提示，带有进度
    UIAlertController *loadingAlert = [UIAlertController alertControllerWithTitle:@"处理中" 
                                                                      message:[NSString stringWithFormat:@"正在处理字体文件... (0/%ld)", (long)urls.count]
                                                               preferredStyle:UIAlertControllerStyleAlert];
    
    [self presentViewController:loadingAlert animated:YES completion:^{
        // 在后台线程处理文件复制
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *enhancePath = [self getWechatEnhancePath];
            
            // 确保目录存在
            if (![self ensureDirectoryExists:enhancePath]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [loadingAlert dismissViewControllerAnimated:YES completion:^{
                        [self showErrorAlertWithTitle:@"导入失败" message:@"无法创建字体存储目录"];
                    }];
                });
                return;
            }
            
            // 处理结果统计
            __block NSInteger successCount = 0;
            __block NSInteger failCount = 0;
            __block NSMutableArray *successFonts = [NSMutableArray array];
            
            // 创建一个组，用于等待所有任务完成
            dispatch_group_t group = dispatch_group_create();
            
            // 创建串行队列处理字体导入，避免并发写入问题
            dispatch_queue_t fontQueue = dispatch_queue_create("com.wechat.enhance.fontImport", DISPATCH_QUEUE_SERIAL);
            
            // 处理每个字体文件
            for (NSInteger index = 0; index < urls.count; index++) {
                NSURL *fontURL = urls[index];
                NSString *fileName = fontURL.lastPathComponent;
                NSString *destinationPath = [enhancePath stringByAppendingPathComponent:fileName];
                
                dispatch_group_enter(group);
                dispatch_async(fontQueue, ^{
                    BOOL hasAccess = [fontURL startAccessingSecurityScopedResource];
                    
                    BOOL success = NO;
                    NSString *fontName = nil;
                    
                    @try {
                        // 如果已存在同名文件，先删除
                        if ([self.fileManager fileExistsAtPath:destinationPath]) {
                            NSError *removeError = nil;
                            [self.fileManager removeItemAtPath:destinationPath error:&removeError];
                        }
                        
                        // 首选方法：直接复制文件
                        NSError *copyError = nil;
                        if ([self.fileManager copyItemAtURL:fontURL toURL:[NSURL fileURLWithPath:destinationPath] error:&copyError]) {
                            // 验证字体文件有效性
                            fontName = [self getFontNameFromPath:destinationPath];
                            if (fontName) {
                                success = YES;
                                
                                // 记录成功导入的字体信息
                                dispatch_sync(dispatch_get_main_queue(), ^{
                                    [successFonts addObject:@{
                                        @"fileName": fileName,
                                        @"fontName": fontName
                                    }];
                                });
                            } else {
                                // 字体名称无效，删除无效文件
                                [self.fileManager removeItemAtPath:destinationPath error:nil];
                            }
                        } 
                        // 备选方法：读取数据再写入
                        else {
                            NSData *fontData = [NSData dataWithContentsOfURL:fontURL options:NSDataReadingMappedIfSafe error:nil];
                            
                            if (fontData && [fontData writeToFile:destinationPath options:NSDataWritingAtomic error:nil]) {
                                // 验证字体文件有效性
                                fontName = [self getFontNameFromPath:destinationPath];
                                if (fontName) {
                                    success = YES;
                                    
                                    dispatch_sync(dispatch_get_main_queue(), ^{
                                        [successFonts addObject:@{
                                            @"fileName": fileName,
                                            @"fontName": fontName
                                        }];
                                    });
                                } else {
                                    // 字体名称无效，删除无效文件
                                    [self.fileManager removeItemAtPath:destinationPath error:nil];
                                }
                            }
                        }
                    } @catch (NSException *exception) {
                        // 处理异常
                    } @finally {
                        // 停止访问安全范围资源
                        if (hasAccess) {
                            [fontURL stopAccessingSecurityScopedResource];
                        }
                        
                        // 更新计数
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            if (success) {
                                successCount++;
                            } else {
                                failCount++;
                            }
                            
                            // 更新进度提示
                            NSInteger processed = successCount + failCount;
                            loadingAlert.message = [NSString stringWithFormat:@"正在处理字体文件... (%ld/%ld)", (long)processed, (long)urls.count];
                        });
                        
                        dispatch_group_leave(group);
                    }
                });
            }
            
            // 等待所有字体处理完成
            dispatch_group_notify(group, dispatch_get_main_queue(), ^{
                // 关闭加载提示
                [loadingAlert dismissViewControllerAnimated:YES completion:^{
                    // 显示处理结果
                    if (successCount > 0) {
                        NSString *resultMessage;
                        if (failCount > 0) {
                            resultMessage = [NSString stringWithFormat:@"共导入 %ld 个字体文件成功，%ld 个文件导入失败。", (long)successCount, (long)failCount];
                        } else {
                            resultMessage = [NSString stringWithFormat:@"成功导入 %ld 个字体文件。", (long)successCount];
                        }
                        
                        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"导入完成" 
                                                                                       message:resultMessage
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                        [successAlert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            // 刷新字体列表
                            [self loadFontsList];
                            [self setupData];
                            [self.tableView reloadData];
                        }]];
                        [self presentViewController:successAlert animated:YES completion:nil];
                    } else if (failCount > 0) {
                        [self showErrorAlertWithTitle:@"导入失败" message:@"所有字体文件导入失败，请确保选择了有效的字体文件。"];
                    }
                }];
            });
        });
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections[section].items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    FontSettingItem *item = self.sections[indexPath.section].items[indexPath.row];
    UITableViewCell *cell;
    
    if (item.itemType == SettingItemTypeSwitch) {
        // 使用基本单元格样式
        cell = [tableView dequeueReusableCellWithIdentifier:@"FontSettingSwitchCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"FontSettingSwitchCell"];
        }
        
        // 配置单元格基本属性
        cell.textLabel.text = item.title;
        
        if (item.iconName) {
            UIImage *icon = [UIImage systemImageNamed:item.iconName];
            cell.imageView.image = icon;
            cell.imageView.tintColor = item.iconColor;
        } else {
            cell.imageView.image = nil;
        }
        
        // 创建开关控件
        UISwitch *switchControl = [[UISwitch alloc] initWithFrame:CGRectZero];
        switchControl.on = item.switchValue;
        switchControl.tag = indexPath.section * 1000 + indexPath.row; // 用于在开关事件中识别是哪个设置项
        [switchControl addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchControl;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (item.detail) {
        // 使用带详情的单元格样式
        cell = [tableView dequeueReusableCellWithIdentifier:@"FontSettingDetailCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"FontSettingDetailCell"];
        }
        
        // 配置单元格基本属性
        cell.textLabel.text = item.title;
        cell.detailTextLabel.text = item.detail;
        
        if (item.iconName) {
            UIImage *icon = [UIImage systemImageNamed:item.iconName];
            cell.imageView.image = icon;
            cell.imageView.tintColor = item.iconColor;
        } else {
            cell.imageView.image = nil;
        }
        
        // 根据项目类型设置单元格样式
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else {
        // 使用基本单元格样式
        cell = [tableView dequeueReusableCellWithIdentifier:@"FontSettingCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"FontSettingCell"];
        }
        
        // 配置单元格基本属性
        cell.textLabel.text = item.title;
        
        if (item.iconName) {
            UIImage *icon = [UIImage systemImageNamed:item.iconName];
            cell.imageView.image = icon;
            cell.imageView.tintColor = item.iconColor;
        } else {
            cell.imageView.image = nil;
        }
        
        // 根据项目类型设置单元格样式
        if (item.itemType == SettingItemTypeAction) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section].header;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    FontSettingItem *item = self.sections[indexPath.section].items[indexPath.row];
    
    // 如果有actionBlock，执行它
    if (item.actionBlock) {
        item.actionBlock();
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

// 支持滑动删除字体
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // 只允许字体列表部分进行编辑
    return [self.sections[indexPath.section].header isEqualToString:@"已添加字体"];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.sections[indexPath.section].header isEqualToString:@"已添加字体"]) {
        return UITableViewCellEditingStyleDelete;
    }
    return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && 
        [self.sections[indexPath.section].header isEqualToString:@"已添加字体"]) {
        
        // 获取要删除的字体
        NSDictionary *fontDict = self.fontsList[indexPath.row];
        NSString *fontPath = fontDict[@"path"];
        
        // 显示确认对话框
        [self showAlertWithTitle:@"确认删除" 
                        message:@"确定要删除这个字体文件吗？"
                destructiveTitle:@"删除"
                    cancelTitle:@"取消"
              destructiveAction:^{
                  [self deleteFont:fontPath];
              }];
    }
}

// 修改开关值变化方法，通过tag获取设置项
- (void)switchValueChanged:(UISwitch *)sender {
    NSInteger section = sender.tag / 1000;
    NSInteger row = sender.tag % 1000;
    
    // 确保索引有效
    if (section < self.sections.count) {
        FontSettingSection *settingSection = self.sections[section];
        if (row < settingSection.items.count) {
            FontSettingItem *item = settingSection.items[row];
            
            // 更新设置项状态
            item.switchValue = sender.isOn;
            
            // 执行回调
            if (item.switchValueChanged) {
                item.switchValueChanged(sender.isOn);
            }
        }
    }
}

@end 
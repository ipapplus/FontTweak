export DEBUG=0
export FINALPACKAGE=1
export THEOS=/opt/theos

# 项目名称
TWEAK_NAME = FontTweak

# 目标设备最低版本
export ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

# 源文件
FontTweak_FILES = Hooks/GestureHooks.xm \
                  Hooks/CustomFontHooks.xm \
                  Controllers/CSFontSettingsViewController.m

# 编译标志
FontTweak_CFLAGS = -fobjc-arc \
                   -I$(THEOS_PROJECT_DIR)/Headers \
                   -I$(THEOS_PROJECT_DIR)/Hooks \
                   -Wno-error

# 框架依赖
FontTweak_FRAMEWORKS = UIKit Foundation CoreText UniformTypeIdentifiers

# 包含 Theos make 系统
include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

clean::
	@echo -e "\033[31m==>\033[0m 正在清理......"
	@rm -rf .theos

after-all::
	@echo -e "\033[32m==>\033[0m 编译完成！生成dylib文件路径: $(THEOS_OBJ_DIR)"
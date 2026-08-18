# -*- coding: utf-8 -*-
"""App/Sozoro.xcodeproj を作り直す。Swift ファイルを足したら、これを走らせる。"""
import uuid, os, glob, re
G = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(G, '..')
os.chdir(ROOT)

SRC = sorted(os.path.basename(p) for p in glob.glob('App/Sozoro/*.swift'))
print('ソース', len(SRC), '本:', ', '.join(SRC))

def oid(): return uuid.uuid4().hex[:24].upper()
K = ['rootObj','mainGroup','productsGroup','appGroup','assetsRef','productRef','target',
     'buildConfigList','projConfigList','debugProj','releaseProj','debugTgt','releaseTgt',
     'sourcesPhase','resourcesPhase','frameworksPhase','pkgRef','pkgDep','pkgBuildFile','assetsBF']
I = {k: oid() for k in K}
F = {n: (oid(), oid()) for n in SRC}          # (fileRef, buildFile)

def sec(fmt): return '\n'.join(fmt(n) for n in SRC)
fileRefs   = sec(lambda n: f'\t\t{F[n][0]} /* {n} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{n}"; sourceTree = "<group>"; }};')
buildFiles = sec(lambda n: f'\t\t{F[n][1]} /* {n} in Sources */ = {{isa = PBXBuildFile; fileRef = {F[n][0]} /* {n} */; }};')
children   = sec(lambda n: f'\t\t\t\t{F[n][0]} /* {n} */,')
sources    = sec(lambda n: f'\t\t\t\t{F[n][1]} /* {n} in Sources */,')

SETTINGS = '''				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Sozoro needs your position to work out where to send you, and how far you still have to walk.";
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				INFOPLIST_KEY_CFBundleDisplayName = Sozoro;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = NO;
				LD_RUNPATH_SEARCH_PATHS = ( "$(inherited)", "@executable_path/Frameworks" );
				MARKETING_VERSION = 0.1;
				PRODUCT_BUNDLE_IDENTIFIER = "dev.sozoro.app";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;'''

pbx = f'''// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{buildFiles}
		{I['assetsBF']} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {I['assetsRef']} /* Assets.xcassets */; }};
		{I['pkgBuildFile']} /* SozoroCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {I['pkgDep']} /* SozoroCore */; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{fileRefs}
		{I['assetsRef']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};
		{I['productRef']} /* Sozoro.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Sozoro.app; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{I['frameworksPhase']} = {{
			isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647;
			files = ( {I['pkgBuildFile']} /* SozoroCore in Frameworks */, );
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{I['mainGroup']} = {{
			isa = PBXGroup;
			children = ( {I['appGroup']} /* Sozoro */, {I['productsGroup']} /* Products */, );
			sourceTree = "<group>";
		}};
		{I['appGroup']} /* Sozoro */ = {{
			isa = PBXGroup;
			children = (
{children}
				{I['assetsRef']} /* Assets.xcassets */,
			);
			path = Sozoro; sourceTree = "<group>";
		}};
		{I['productsGroup']} /* Products */ = {{
			isa = PBXGroup;
			children = ( {I['productRef']} /* Sozoro.app */, );
			name = Products; sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{I['target']} /* Sozoro */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {I['buildConfigList']};
			buildPhases = ( {I['sourcesPhase']}, {I['frameworksPhase']}, {I['resourcesPhase']}, );
			buildRules = (); dependencies = (); name = Sozoro;
			packageProductDependencies = ( {I['pkgDep']} /* SozoroCore */, );
			productName = Sozoro; productReference = {I['productRef']} /* Sozoro.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{I['rootObj']} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{ BuildIndependentTargetsInParallel = 1; LastUpgradeCheck = 1600;
				TargetAttributes = {{ {I['target']} = {{ CreatedOnToolsVersion = 16.0; }}; }}; }};
			buildConfigurationList = {I['projConfigList']};
			compatibilityVersion = "Xcode 14.0"; developmentRegion = en;
			hasScannedForEncodings = 0; knownRegions = ( en, Base, ja );
			mainGroup = {I['mainGroup']};
			packageReferences = ( {I['pkgRef']} /* XCLocalSwiftPackageReference ".." */, );
			productRefGroup = {I['productsGroup']} /* Products */;
			projectDirPath = ""; projectRoot = "";
			targets = ( {I['target']} /* Sozoro */, );
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{I['resourcesPhase']} = {{
			isa = PBXResourcesBuildPhase; buildActionMask = 2147483647;
			files = ( {I['assetsBF']} /* Assets.xcassets in Resources */, );
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{I['sourcesPhase']} = {{
			isa = PBXSourcesBuildPhase; buildActionMask = 2147483647;
			files = (
{sources}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{I['debugProj']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES;
				ENABLE_STRICT_OBJC_MSGSEND = YES; GCC_NO_COMMON_BLOCKS = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0; ONLY_ACTIVE_ARCH = YES; SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone"; SWIFT_VERSION = 5.0;
				DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_TESTABILITY = YES; GCC_OPTIMIZATION_LEVEL = 0;
			}};
			name = Debug;
		}};
		{I['releaseProj']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES;
				ENABLE_STRICT_OBJC_MSGSEND = YES; GCC_NO_COMMON_BLOCKS = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule; SWIFT_VERSION = 5.0;
				VALIDATE_PRODUCT = YES; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
			}};
			name = Release;
		}};
		{I['debugTgt']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{SETTINGS}
			}};
			name = Debug;
		}};
		{I['releaseTgt']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{SETTINGS}
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{I['projConfigList']} = {{
			isa = XCConfigurationList;
			buildConfigurations = ( {I['debugProj']} /* Debug */, {I['releaseProj']} /* Release */, );
			defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;
		}};
		{I['buildConfigList']} = {{
			isa = XCConfigurationList;
			buildConfigurations = ( {I['debugTgt']} /* Debug */, {I['releaseTgt']} /* Release */, );
			defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
		{I['pkgRef']} /* XCLocalSwiftPackageReference ".." */ = {{
			isa = XCLocalSwiftPackageReference; relativePath = ..;
		}};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		{I['pkgDep']} /* SozoroCore */ = {{
			isa = XCSwiftPackageProductDependency; productName = SozoroCore;
		}};
/* End XCSwiftPackageProductDependency section */
	}};
	rootObject = {I['rootObj']} /* Project object */;
}}
'''
os.makedirs('App/Sozoro.xcodeproj/xcshareddata/xcschemes', exist_ok=True)
open('App/Sozoro.xcodeproj/project.pbxproj','w').write(pbx)

scheme = open(os.path.join(G, 'scheme.template')).read().replace('__TARGET__', I['target'])
open('App/Sozoro.xcodeproj/xcshareddata/xcschemes/Sozoro.xcscheme','w').write(scheme)
print('project.pbxproj と scheme を書き直した')

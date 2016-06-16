//
//  JFMacro.h
//  JFPlayer
//
//  Created by fan on 16/6/16.
//  Copyright © 2016年 fan. All rights reserved.
//

#ifndef JFMacro_h
#define JFMacro_h


#define kNavHieght  64
#define __BlockObject(object)           __weak typeof(object)__blockObject = object


/**
 *  App Main Frame
 */
#define Application_Landscapte_Width    MAX([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)
#define Application_Landscapte_Height   MIN([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)

#define Application_Rect                [[UIScreen mainScreen] bounds]
#define Application_Width                [[UIScreen mainScreen] bounds].size.width
#define Application_Height                [[UIScreen mainScreen] bounds].size.height


/**
 *  获取颜色
 */
#define RGB_COLOR(r, g, b) [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1.0]
#define RGB_COLOR_ALPHA(r, g, b, a) [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a]

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]
#define UIColorFromRGB_ALPHA(rgbValue, alphaValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:alphaValue]


#endif /* JFMacro_h */

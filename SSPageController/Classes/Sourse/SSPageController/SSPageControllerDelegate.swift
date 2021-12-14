//
//  SSPageControllerDelegate.swift
//
//
//  Created by Shine on 2020/2/18.
//  Copyright © 2020 Shine. All rights reserved.
//
import UIKit
import Foundation
@objc protocol SSPageControllerDelegate: NSObjectProtocol {
    /**
     *  If the child controller is heavy, put some work in this method. This method will only be called when the controller is initialized and stop scrolling. (That means if the controller is cached and hasn't released will never call this method.)
     *
     *  @param pageController The parent controller (JWPageController)
     *  @param viewController The viewController first show up when scroll stop.
     *  @param info           A dictionary that includes some infos, such as: `index` / `title`
     */
    @objc optional func pageController(_ pageController: SSPageController, lazyLoadViewController viewController: UIViewController, withInfo info: [String:Any])
    
    /**
     *  Called when a viewController will be cached. You can clear some data if it's not reusable.
     *
     *  @param pageController The parent controller (JWPageController)
     *  @param viewController The viewController will be cached.
     *  @param info           A dictionary that includes some infos, such as: `index` / `title`
     */
    @objc optional func pageController(_ pageController: SSPageController, willCachedViewController viewController: UIViewController, withInfo info: [String:Any])
    
    /**
     *  Called when a viewController will be appear to user's sight. Do some preparatory methods if needed.
     *
     *  @param pageController The parent controller (JWPageController)
     *  @param viewController The viewController will appear.
     *  @param info           A dictionary that includes some infos, such as: `index` / `title`
     */
    @objc optional func pageController(_ pageController: SSPageController, willEnterViewController viewController: UIViewController, withInfo info: [String:Any])
    
    /**
     *  Called when a viewController will fully displayed, that means, scrollView have stopped scrolling and the controller's view have entirely displayed.
     *
     *  @param pageController The parent controller (JWPageController)
     *  @param viewController The viewController entirely displayed.
     *  @param info           A dictionary that includes some infos, such as: `index` / `title`
     */
    @objc optional func pageController(_ pageController: SSPageController, didEnterViewController viewController: UIViewController, withInfo info: [String: Any])
    
    /*
     再次点击menuview同一按钮回调，主要用于是否刷新列表
     */
    @objc optional func pageController(_ pageController: SSPageController, didClickIndexAgainWithIndex index: Int)
    
    /*
     页面点击item 触发事件
     */
    @objc optional func pageController(_ pageController: SSPageController, didSelesctedIndex index: Int, currentIndex: Int)
}

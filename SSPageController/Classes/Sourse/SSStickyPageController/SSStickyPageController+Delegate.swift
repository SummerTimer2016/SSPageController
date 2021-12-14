//
//  SSStickyPageController+Delegate.swift
//  SSPageController
//
//  Created by Summer on 2021/12/14.
//

import UIKit

protocol SStickyPageControllerDelegate:SSPageControllerDelegate {
    /**
     Asks the page if the scrollview should scroll with the subview.
     
     @param scrollView The scrollview. This is the object sending the message.
     @param subview    An instance of a sub view.
     
     @return YES to allow scrollview and subview to scroll together. YES by default.
     */
    func pageController(pageController:SStickyPageController,shouldScrollWithSubview subview:UIScrollView) -> Bool
}

extension SStickyPageControllerDelegate {
    func pageController(pageController:SStickyPageController,shouldScrollWithSubview subview:UIScrollView) -> Bool{
        return false
    }
}

//
//  SSPageScrollView.swift
//
//
//  Created by Shine on 2020/2/18.
//  Copyright © 2020 Shine. All rights reserved.
//


import UIKit

class SSPageScrollView: UIScrollView {
    
    /*
     // Only override draw() if you perform custom drawing.
     // An empty implementation adversely affects performance during animation.
     override func draw(_ rect: CGRect) {
     // Drawing code
     }
     */
    
}

extension SSPageScrollView {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if otherGestureRecognizer is UIPanGestureRecognizer {
            if let otherGesView = otherGestureRecognizer.view, NSStringFromClass(otherGesView.classForCoder) == "UITableViewWrapperView" {
                return true
            }
        }
        
        return false
    }
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIPanGestureRecognizer {
            let tmpGesture = gestureRecognizer as? UIPanGestureRecognizer
            let translation  = tmpGesture?.translation(in: tmpGesture?.view)
            /* 当scrollView滑到初始位置时，再滑动就让返回手势生效
             * translation.x > 0 表示向右滑动 translation.x <= 0 表示向左滑动
             */
            if (self.contentOffset.x <= 0 && (translation?.x ?? 0) > 0) {
                return false
            }
        }
        return true
    }
}

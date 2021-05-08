//
//  SSMagicScrollView.swift
//  JYLMOperation
//
//  Created by Summer on 2021/4/27.
//

import UIKit

private class MXScrollViewDelegateForwarder: NSObject, SSMagicScrollViewDelegate {
    weak var delegate: SSMagicScrollViewDelegate?
}

class SSMagicScrollView: UIScrollView {
    ///头部滑动视图最小高度
    var minimumHeaderViewHeight: CGFloat = 0.0
    ///头部滑动视图最大高度
    var maximumHeaderViewHeight: CGFloat = 0.0
    /// Delegate instance that adopt the MXScrollViewDelegate.
    dynamic weak var myDelegate: SSMagicScrollViewDelegate? {
        set {
            self.forwarder?.delegate = newValue
            // Scroll view delegate caches whether the delegate responds to some of the delegate
            // methods, so we need to force it to re-evaluate if the delegate responds to them
            super.delegate = nil;
            super.delegate = self.forwarder;
        }
        
        get {
            return self.forwarder?.delegate
        }
    }
    
    ///滑动页面回调
    private var forwarder: MXScrollViewDelegateForwarder?
    ///监听当前滑动视图数量，并存放到数组内
    private var observedViews: [UIScrollView]?
    ///是否监听中
    private var isObserving = false
    ///是否锁定中（锁定中监听）
    private var lock = false
    
    private var kMXScrollViewKVOContext =  "kMXScrollViewKVOContext"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
extension SSMagicScrollView {
    private func initialize() {
        self.forwarder = MXScrollViewDelegateForwarder()
        super.delegate = forwarder
        
        showsVerticalScrollIndicator = false
        isDirectionalLockEnabled = true
        bounces = true
        
        if #available(iOS 11.0, *) {
            contentInsetAdjustmentBehavior = .never
        }
        
        panGestureRecognizer.cancelsTouchesInView = false
        
        observedViews = [UIScrollView]()
        addObserver(self, forKeyPath: "contentOffset", options: [.new,.old], context: &kMXScrollViewKVOContext)
        isObserving = true
    }
    // MARK: ---- UIGestureRecognizerDelegate ----
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer.view == self {
            return false
        }
        
        // Ignore other gesture than pan
        if !(gestureRecognizer is UIPanGestureRecognizer) {
            return false
        }
        
        // Lock horizontal pan gesture.
        let velocity = (gestureRecognizer as? UIPanGestureRecognizer)?.velocity(in: self)
        if abs(Float(velocity?.x ?? 0.0)) > abs(Float(velocity?.y ?? 0.0)) {
            return false
        }
        
        if !(otherGestureRecognizer.view is UIScrollView) {
            return false
        }
        
        let scrollView = otherGestureRecognizer.view as? UIScrollView
        
        // Tricky case: UITableViewWrapperView
        if scrollView?.superview is UITableView {
            return false
        }
        //        if scrollView.superview is (NSClassFromString("UITableViewCellContentView")) {
        //            return false
        //        }
        
        var shouldScroll = true
        
        if let delegateNil = self.myDelegate {
            shouldScroll = delegateNil.scrollView(self, shouldScrollWithSubview: scrollView)
        }
        
        if shouldScroll {
            addObserver(to: scrollView)
        }
        
        return shouldScroll
    }
    // MARK: KVO
    private func addObserver(to scrollView: UIScrollView?) {
        lock = ((scrollView?.contentOffset.y ?? 0.0) > -(scrollView?.contentInset.top ?? 0.0))
        scrollView?.addObserver(
            self,
            forKeyPath: "contentOffset",
            options: [.old, .new],
            context: &kMXScrollViewKVOContext)
    }
    private func removeObserver(from scrollView: UIScrollView?) {
        scrollView?.removeObserver(
            self,
            forKeyPath: "contentOffset",
            context: &kMXScrollViewKVOContext)
    }
}

extension SSMagicScrollView: UIGestureRecognizerDelegate {
    
}

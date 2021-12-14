//
//  SSMagicScrollView.swift
//  JYLMDirver
//
//  Created by Summer on 2021/4/27.
//

import UIKit
import Foundation

private class MXScrollViewDelegateForwarder: NSObject,SSMagicScrollViewDelegate {
    weak var delegate: SSMagicScrollViewDelegate?
    
    override func responds(to selector: Selector!) -> Bool {
        return delegate?.responds(to: selector) ?? false || super.responds(to: selector)
    }
//
//    func forwardInvocation(_ invocation: NSInvocation) {
//        invocation.invoke(withTarget: delegate)
//    }
    // MARK: <UIScrollViewDelegate>
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        (scrollView as? SSMagicScrollView)?.scrollViewDidEndDecelerating(scrollView)
        if ((delegate?.responds(to: #function)) != nil) {
            delegate?.scrollViewDidEndDecelerating?(scrollView)
        }
    }
}

class SSMagicScrollView: UIScrollView {
    ///头部滑动视图最小高度
    var minimumHeaderViewHeight: CGFloat = 0.0
    ///头部滑动视图最大高度
    var maximumHeaderViewHeight: CGFloat = 0.0

    // MARK:-------- Properties get&set ---------
    /// Delegate instance that adopt the MXScrollViewDelegate.
    public  weak var delegateMS: SSMagicScrollViewDelegate? {
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
    private lazy var observedViews: [UIScrollView] = {
       return [UIScrollView]()
    }()
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
    
    deinit {
        self.removeObserver(self,
                            forKeyPath: NSStringFromSelector(#selector(getter: contentOffset)),
                            context: &kMXScrollViewKVOContext)
        self.removeObservedViews()
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
        addObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: contentOffset)), options: [.new,.old], context: &kMXScrollViewKVOContext)
        isObserving = true
    }
    
    private func GetClassFromString(_ classString: String) -> AnyClass? {
        guard let bundleName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String else {
            return nil
        }
        var anyClass: AnyClass? = NSClassFromString(bundleName + "." + classString)
        if (anyClass == nil) {
            anyClass = NSClassFromString(classString)
        }
        return anyClass
    }
}
// MARK: KVO
extension SSMagicScrollView {
    ///添加Observer监听
    private func addObserver(to scrollView: UIScrollView?) {
        lock = ((scrollView?.contentOffset.y ?? 0.0) > -(scrollView?.contentInset.top ?? 0.0))
        scrollView?.addObserver(
            self,
            forKeyPath: NSStringFromSelector(#selector(getter: contentOffset)),
            options: [.old, .new],
            context: &kMXScrollViewKVOContext)
    }
    ///移除Observer监听
    private func removeObserver(from scrollView: UIScrollView?) {
        scrollView?.removeObserver(
            self,
            forKeyPath: NSStringFromSelector(#selector(getter: contentOffset)),
            context: &kMXScrollViewKVOContext)
    }
}

// MARK:-------- observe ---------
extension SSMagicScrollView {
    //This is where the magic happens...
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &kMXScrollViewKVOContext
            && (keyPath == NSStringFromSelector(#selector(getter: contentOffset))) {
            guard let changeValue = change else {return}
            guard let objectValue = object else {return}
            guard let new = changeValue[NSKeyValueChangeKey.newKey] as? CGPoint else {return}
            guard let old = changeValue[NSKeyValueChangeKey.oldKey] as? CGPoint else {return}
            
            let diff = old.y - new.y
            if (diff == 0) || !isObserving {return}
            
            let maximumContentOffsetY = maximumHeaderViewHeight - minimumHeaderViewHeight
            if objectValue is SSMagicScrollView {
                //Adjust self scroll offset when scroll down
                if (diff > 0 && lock) {
                    self.scrollView(self, setContentOffset: old)
                }else if contentOffset.y < -contentInset.top && !bounces {
                    self.scrollView(self, setContentOffset: CGPoint(x: contentOffset.x, y: -contentInset.top))
                } else if contentOffset.y > maximumContentOffsetY {
                    self.scrollView(self, setContentOffset: CGPoint(x: contentOffset.x, y: maximumContentOffsetY))
                } else {}
                
            }else {
                //Adjust the observed scrollview's content offset
                if let scrollView = (object as? UIScrollView) {
                    lock = ((scrollView.contentOffset.y) > -(scrollView.contentInset.top))
                    //Manage scroll up
                    if contentOffset.y < maximumContentOffsetY && lock && diff < 0 {
                        self.scrollView(scrollView, setContentOffset: old)
                    }
                    if !lock && ((contentOffset.y > -contentInset.top) || bounces) {
                        self.scrollView(scrollView, setContentOffset: CGPoint(x: scrollView.contentOffset.x, y: -scrollView.contentInset.top))
                    }
                }
                
            }
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    
}

// MARK:-------- Scrolling views handlers ---------
extension SSMagicScrollView {
    ///添加监听视图
    private func addObservedView(_ scrollView: UIScrollView?) {
        if let scrollView = scrollView {
            if !observedViews.contains(scrollView) {
                observedViews.append(scrollView)
                addObserver(to: scrollView)
            }
        }
    }
    ///移除监听视图
    private func removeObservedViews() {
        for scrollView in observedViews {
            removeObserver(from: scrollView)
        }
        observedViews.removeAll()
    }
    ///设定当前页面滑动
    private func scrollView(_ scrollView: UIScrollView?, setContentOffset offset: CGPoint) {
        isObserving = false
        scrollView?.contentOffset = offset
        isObserving = true
    }
}
// MARK:-------- UIScrollViewDelegate ---------
extension SSMagicScrollView:UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        lock = false
        removeObservedViews()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            lock = false
            removeObservedViews()
        }
    }
}

extension SSMagicScrollView: UIGestureRecognizerDelegate {
    // MARK: ---- UIGestureRecognizerDelegate ----
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer.view == self {
            return false
        }
        // Ignore other gesture than pan
        if !(gestureRecognizer.isKind(of: UIPanGestureRecognizer.self)) {
            return false
        }
        
        // Lock horizontal pan gesture.
        let velocity = (gestureRecognizer as? UIPanGestureRecognizer)?.velocity(in: self)
        if abs(Float(velocity?.x ?? 0.0)) > abs(Float(velocity?.y ?? 0.0)) {
            return false
        }
        
        if !(otherGestureRecognizer.view?.isKind(of: UIScrollView.self) ?? false) {
            return false
        }
        let scrollView = otherGestureRecognizer.view as? UIScrollView
        // Tricky case: UITableViewWrapperView
        if (scrollView?.superview?.isKind(of: UITableView.self) ?? false) {
            return false
        }
        //tableview on the MXScrollView
        if let className = GetClassFromString("UITableViewCellContentView"),
           (scrollView?.superview?.isKind(of: className) ?? false) {
            return false
        }
        var shouldScroll = true
        
        if let delegateNil = self.delegateMS {
            shouldScroll = delegateNil.scrollView(self, shouldScrollWithSubview: scrollView ?? UIScrollView())
        }
        
        if shouldScroll {
            addObserver(to: scrollView)
        }
        
        return shouldScroll
    }
}

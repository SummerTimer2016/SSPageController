//
//  SSStickyPageController.swift
//  SSPageController
//
//  Created by Summer on 2021/12/14.
//

import UIKit
/**
 The self.view is custom UIScrollView
 */
class SStickyPageController: SSPageController {
    
    // MARK:--------  WMMagicScrollView ContentView ---------
    
    private lazy var contentView: SSMagicScrollView = {
        let _contentView = SSMagicScrollView(frame: UIScreen.main.bounds)
        return _contentView
    }()
    
    
    // MARK:--------  setter & getter ---------
    /**
     It's determine the sticky locatio.
     */
    public var minimumHeaderViewHeight:CGFloat {
        set {
            self.contentView.minimumHeaderViewHeight = newValue
        }
        get {
            return self.contentView.minimumHeaderViewHeight
        }
    }
    /**
     The custom headerView's height, default 0 means no effective.
     */
    public var maximumHeaderViewHeight:CGFloat {
        set {
            self.contentView.maximumHeaderViewHeight = newValue
        }
        get {
            return self.contentView.maximumHeaderViewHeight
        }
    }
    /**
     The menuView's height, default 44
     */
    public var menuViewHeight:CGFloat = 0
    
    override func loadView() {
        self.view = self.contentView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    
    
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
}
extension SStickyPageController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.contentView.contentSize = CGSize(width: view.bounds.width,
                                              height: view.bounds.height + maximumHeaderViewHeight)
    }
}
// MARK:--------  SSMagicScrollViewDelegate ---------
extension SStickyPageController:SSMagicScrollViewDelegate {
    func scrollView(_ scrollView: SSMagicScrollView,
                    shouldScrollWithSubview subview: UIScrollView) -> Bool {
        if subview is SSMagicScrollView {
            return false
        }
        if self.delegate is SStickyPageControllerDelegate {
            weak var delegateTicky = self.delegate as? SStickyPageControllerDelegate
            if let delegateTickyNoNil = delegateTicky {
                return delegateTickyNoNil.pageController(pageController: self, shouldScrollWithSubview: subview)
            }
        }
        return true
    }
    
    
    
}
// MARK:-------- SSPageControllerDataSource ---------
extension SStickyPageController {
    override func pageController(_ pageController: SSPageController, preferredFrameForMenuView menuView: SSMenuView?) -> CGRect {
        var originY = maximumHeaderViewHeight
        if originY <= 0 {
            let navigationBar = navigationController?.navigationBar
            originY = ((showOnNavigationBar && navigationBar != nil) ? 0 : navigationBar?.frame.maxY) ?? 0.0
        }
        return CGRect(x: 0, y: originY, width: view.frame.width, height: menuViewHeight)
    }
    override func pageController(_ pageController: SSPageController, preferredFrameForContentView contentView: SSPageScrollView?) -> CGRect {
        let preferredFrameForMenuView = self.pageController(pageController, preferredFrameForMenuView: pageController.menuView)
        let tabBar = tabBarController?.tabBar
        guard let tabBarHeight = (tabBar != nil && !(tabBar?.isHidden ?? false) ? tabBar?.frame.height : 0) else {return .zero }
        return CGRect(
            x: 0,
            y: preferredFrameForMenuView.maxY,
            width: preferredFrameForMenuView.width,
            height: view.frame.height - minimumHeaderViewHeight - preferredFrameForMenuView.height - tabBarHeight)
    }
}

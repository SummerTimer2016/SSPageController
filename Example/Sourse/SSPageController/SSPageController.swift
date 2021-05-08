//
//  SSPageController.swift
//
//
//  Created by Shine on 2020/2/18.
//  Copyright © 2020 Shine. All rights reserved.
//


import UIKit

enum SSPageControllerPreloadPolicy: Int {
    case never = 0 // Never pre-load controller.
    case neighbour = 1// Pre-load the controller next to the current.
    case near = 2// Pre-load 2 controllers near the current.
}

extension NSNotification.Name {
    static let SSControllerDidAddToSuperViewNotification = NSNotification.Name("SSControllerDidAddToSuperViewNotification")
    static let SSControllerDidFullyDisplayedNotification = NSNotification.Name("SSControllerDidFullyDisplayedNotification")
}


let kSSUndefinedIndex: Int = -1;
let kSSControllerCountUndefined: Int = -1;

class SSPageController: JYLMBaseViewController {
    
    //MARK:可设置属性
    weak var delegate: SSPageControllerDelegate?
    weak var dataSource: SSPageControllerDataSource?
    
    /**
     *  Values and keys can set properties when initialize child controlelr (it's KVC)
     *  values keys 属性可以用于初始化控制器的时候为控制器传值(利用 KVC 来设置)
     使用时请确保 key 与控制器的属性名字一致！！(例如：控制器有需要设置的属性 type，那么 keys 所放的就是字符串 @"type")
     */
    var values: [AnyObject]?
    var keys: [String]?
    
    
    /**
     *  各个控制器的 class, 例如:[UITableViewController class]
     *  Each controller's class, example:[UITableViewController class]
     */
    var viewControllerClasses: [UIViewController.Type]?
    
    /**
     *  各个控制器标题
     *  Titles of view controllers in page controller.
     */
    var titles: [String]?
    
    /**
     *  当前显示的控制器
     *  the view controller showing.
     */
    private(set) var currentViewController:  UIViewController?
    
    /**
     *  设置选中几号 item
     *  To select item at index
     */
    
    private var _selectIndex: Int = 0
    
    var selectIndex: Int {
        set {
            _selectIndex = newValue
            
            markedSelectIndex = kSSUndefinedIndex;
            
            if let menuView = self.menuView, hasInited {
                menuView.selectItemAtIndex(newValue)
            }else {
                markedSelectIndex = newValue
                var vc = self.memCache.object(forKey: NSNumber(value: newValue))
                if vc == nil {
                    vc = self.initializeViewControllerAtIndex(newValue)
                    if vc != nil {
                        self.memCache.setObject(vc!, forKey: NSNumber(value: newValue))
                    }
                }
                currentViewController = vc
            }
        }
        get {
            return _selectIndex
        }
    }
    
    /**
     *  点击的 MenuItem 是否触发滚动动画 默认为 true
     *  Whether to animate when press the MenuItem
     */
    var pageAnimatable = true
    
    /** 是否自动通过字符串计算 MenuItem 的宽度，默认为 false. */
    var automaticallyCalculatesItemWidths = false
    
    
    /** Whether the controller can scroll. Default is YES. */
    var scrollEnable = true {
        willSet {
            if let scrollView = self.scrollView {
                scrollView.isScrollEnabled = scrollEnable
            }
        }
    }
    
    /**
     *  选中时的标题尺寸
     *  The title size when selected (animatable)
     */
    var titleSizeSelected: CGFloat = 16
    
    /**
     *  非选中时的标题尺寸
     *  The normal title size (animatable)
     */
    var titleSizeNormal: CGFloat = 16
    
    /**
     *  标题选中时的颜色, 颜色是可动画的.
     *  The title color when selected, the color is animatable.
     */
    var titleColorSelected: UIColor = UIColor.lightGray
    
    /**
     *  标题非选择时的颜色, 颜色是可动画的.
     *  The title's normal color, the color is animatable.
     */
    var titleColorNormal: UIColor = UIColor.black
    
    /**
     *  标题的字体名字
     *  The name of title's font
     */
    var titleFontName: String?
    /**
     *  标题的字体名字
     *  The name of title's font
     */
    var titleSelectFontName: String?
    
    /**
     *  每个 MenuItem 的宽度
     *  The item width,when all are same,use this property
     */
    var menuItemWidth: CGFloat = 65.0
    
    /**
     *  各个 MenuItem 的宽度，可不等
     *  Each item's width, when they are not all the same, use this property, Put `CGFloat` in this array.
     */
    var itemsWidths: [CGFloat]?
    
    /**
     *  Menu view 的样式，默认为无下划线
     *  Menu view's style, now has two different styles, 'Line','default'
     */
    var menuViewStyle: SSMenuViewStyle = .styleDefault
    
    var menuViewLayoutMode: SSMenuViewLayoutMode = .scatter
    /**
     *  进度条的填充图片，若该属性有值，progressColor属性将无效
     *  The progress's image.if it's not empty,'progressColor' property will be ignored.
     */
    var progressImage:UIImage?
    
    /**
     *  进度条的颜色，默认和选中颜色一致(如果 style 为 Default，则该属性无用)
     *  The progress's color,the default color is same with `titleColorSelected`.If you want to have a different color, set this property.
     */
    var progressColor: UIColor? {
        willSet {
            self.menuView?.adjustLineColor(progressColor)
        }
    }
    
    /**
     *  定制进度条在各个 item 下的宽度
     */
    var progressViewWidths: [CGFloat]? {
        willSet {
            if let menuView = self.menuView {
                menuView.progressWidths = progressViewWidths
            }
        }
    }
    
    /// 定制进度条，若每个进度条长度相同，可设置该属性
    var progressWidth: CGFloat = 0 {
        willSet {
            if progressWidth > 0 {
                var tmp = [CGFloat]()
                
                for _ in 0..<childControllersCount {
                    tmp.append(progressWidth)
                }
                
                self.progressViewWidths = tmp
            }
        }
    }
    
    /// 调皮效果，用于实现腾讯视频新效果，请设置一个较小的 progressWidth
    var progressViewIsNaughty: Bool? {
        willSet {
            if let isNaughty = progressViewIsNaughty {
                self.menuView?.progressViewIsNaughty = isNaughty
            }
        }
    }
    
    /**
     *  是否发送在创建控制器或者视图完全展现在用户眼前时通知观察者，默认为不开启，如需利用通知请开启
     *  Whether notify observer when finish init or fully displayed to user, the default is false.
     *  See `JWPageConst.h` for more information.
     */
    var postNotification = false
    
    /** 缓存的机制，默认为无限制 (如果收到内存警告, 会自动切换) */
    var cachePolicy: SSPageControllerCachePolicy = .noLimit {
        willSet {
            if (cachePolicy != .disabled) {
                self.memCache.countLimit = cachePolicy.rawValue
            }
        }
    }
    
    /** 预加载机制，在停止滑动的时候预加载 n 页 */
    var preloadPolicy: SSPageControllerPreloadPolicy = .never
    
    /** Whether ContentView bounces */
    var bounces: Bool = false
    
    /**
     *  是否作为 NavigationBar 的 titleView 展示，默认 false
     *  Whether to show on navigation bar, the default value is `false`
     */
    var showOnNavigationBar = false {
        willSet {
            if showOnNavigationBar != newValue {
                if let menuView = self.menuView {
                    menuView.removeFromSuperview()
                    self.ss_addMenuView()
                    self.forceLayoutSubviews()
                    menuView.slideMenuAtProgress(CGFloat(selectIndex))
                }
            }
        }
    }
    
    /**
     *  用代码设置 contentView 的 contentOffset 之前，请设置 startDragging = YES
     *  Set startDragging = YES before set contentView.contentOffset = xxx;
     */
    var startDragging = false
    
    /** 下划线进度条的高度 */
    var progressHeight: CGFloat = SSUNDEFINED_VALUE
    
    /**
     *  Menu view items' margin / make sure it's count is equal to (controllers' count + 1),default is 0
     顶部菜单栏各个 item 的间隙，因为包括头尾两端，所以确保它的数量等于控制器数量 + 1, 默认间隙为 0
     */
    var itemsMargins: [CGFloat]?
    
    /**
     *  set itemMargin if all margins are the same, default is 0
     如果各个间隙都想同，设置该属性，默认为 0
     */
    var itemMargin: CGFloat?
    
    /** progressView 到 menuView 底部的距离 */
    var progressViewBottomSpace: CGFloat?
    
    /** progressView's cornerRadius */
    var progressViewCornerRadius: CGFloat = SSUNDEFINED_VALUE {
        willSet {
            if let menuView = self.menuView {
                menuView.progressViewCornerRadius = progressViewCornerRadius
            }
        }
    }
    
    var scrollViewBackgroundColor:UIColor? {
        willSet {
            self.scrollView?.backgroundColor = newValue
        }
    }
    
    
    /** 顶部导航栏 */
    weak var menuView: SSMenuView?
    
    /** 内部容器 */
    weak var scrollView: SSPageScrollView?
    
    /** MenuView 内部视图与左右的间距 */
    var menuViewContentMargin: CGFloat? {
        didSet {
            if let contentMargin = menuViewContentMargin {
                self.menuView?.contentMargin = contentMargin
            }
        }
    }
    
    var childControllersCount: Int {
        get {
            if controllerCount == kSSControllerCountUndefined {
                if let dataSource = self.dataSource {
                    if let number = dataSource.numbersOfChildControllersInPageController?(self) {
                        controllerCount = number
                        
                        return controllerCount
                    }
                }
                if let cnt = self.viewControllerClasses?.count {
                    controllerCount = cnt
                }
            }
            return controllerCount
        }
    }
    
    //私有属性
    var targetX: CGFloat = 0
    var contentViewFrame: CGRect = .zero, menuViewFrame: CGRect = .zero
    var hasInited = false
    var shouldNotScroll = false
    var initializedIndex = kSSUndefinedIndex
    var controllerCount = kSSControllerCountUndefined
    var markedSelectIndex = kSSUndefinedIndex
    
    // 用于记录子控制器view的frame，用于 scrollView 上的展示的位置
    var childViewFrames = [CGRect]()
    // 当前展示在屏幕上的控制器，方便在滚动的时候读取 (避免不必要计算)
    lazy var displayVC = [Int: UIViewController]()
    // 用于记录销毁的viewController的位置 (如果它是某一种scrollView的Controller的话)
    lazy var posRecords = [Int: CGPoint]()
    
    // 用于缓存加载过的控制器
    let memCache = NSCache<NSNumber, UIViewController>()
    
    lazy var backgroundCache = [Int: UIViewController]()
    
    // 收到内存警告的次数
    var memoryWarningCount: Int = 0
    
    func forceLayoutSubviews() {
        if childControllersCount <= 0 {
            return
        }
        self.ss_calculateSize()
        self.ss_adjustScrollViewFrame()
        self.ss_adjustMenuViewFrame()
        self.ss_adjustDisplayingViewControllersFrame()
    }
    
    /**
     *  构造方法，请使用该方法创建控制器. 或者实现数据源方法. /
     *  Init method，recommend to use this instead of `-init`. Or you can implement datasource by yourself.
     *
     *  @param classes 子控制器的 class，确保数量与 titles 的数量相等
     *  @param titles  各个子控制器的标题，用 NSString 描述
     *
     *  @return instancetype
     */
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        ss_setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        ss_setup()
    }
    
    convenience init(withViewControllerClasses classes: [UIViewController.Type], andTheirTitles titles: [String]) {
        self.init(nibName: nil, bundle: nil)
        self.viewControllerClasses = classes
        self.titles = titles
    }
    //MARK: -- life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
//        self.automaticallyAdjustsScrollViewInsets = false
        self.view.backgroundColor = UIColor.white
        //        _controllerCount = kJWControllerCountUndefined;//因为项目可能刚开始是未登录，然后还未viewdidload就又登录了，那么这里_controllerCount就不会再初始化，造成crash，所以在viewdidload再初始化一下kJWControllerCountUndefined就可以保证没问题
        if self.childControllersCount == 0{return}
        ss_calculateSize()
        ss_addScrollView()
        ss_addMenuView()
        
        ss_initializedControllerWithIndexIfNeeded(selectIndex)
        currentViewController = displayVC[selectIndex]
        didEnterController(currentViewController, atIndex: selectIndex)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if childControllersCount <= 0 {
            return
        }
        self.forceLayoutSubviews()
        hasInited = true
        self.ss_delaySelectIndexIfNeeded()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        memoryWarningCount += 1
        cachePolicy = .lowMemory
        // 取消正在增长的 cache 操作
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ss_growCachePolicyAfterMemoryWarning), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ss_growCachePolicyToHigh), object: nil)
        memCache.removeAllObjects()
        posRecords.removeAll()
        // 如果收到内存警告次数小于 3，一段时间后切换到模式 Balanced
        if memoryWarningCount < 3 {
            self.perform(#selector(ss_growCachePolicyAfterMemoryWarning), with: nil, afterDelay: 3.0, inModes: [.common])
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ss_growCachePolicyAfterMemoryWarning), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ss_growCachePolicyToHigh), object: nil)
    }
    //MARK: - Delegate
    func infoWithIndex(_ index: Int) -> Dictionary<String, Any> {
        let title = self.titleAtIndex(index)
        return ["title": title, "index": index]
    }
    
    func willCachedController(_ vc: UIViewController, atIndex index: Int) {
        if childControllersCount > 0 {
            let info = self.infoWithIndex(index)
            self.delegate?.pageController?(self, willCachedViewController: vc, withInfo: info)
        }
    }
    
    func willEnterController(_ vc: UIViewController, atIndex index: Int) {
        _selectIndex = index
        if childControllersCount > 0 {
            let info = self.infoWithIndex(index)
            self.delegate?.pageController?(self, willEnterViewController: vc, withInfo: info)
        }
    }
    
    // 完全进入控制器 (即停止滑动后调用)
    func didEnterController(_ vc: UIViewController?, atIndex index: Int) {
        guard childControllersCount > 0 else {
            return
        }
        guard let vc = vc else { return  }
        //wanning selectindex replace index??
        // Post FullyDisplayedNotification
        self.ss_postFullyDisplayedNotificationWithCurrentIndex(index)
        let info = self.infoWithIndex(index)
        self.delegate?.pageController?(self, didEnterViewController: vc, withInfo: info)
        
        // 当控制器创建时，调用延迟加载的代理方法
        if initializedIndex == index {
            self.delegate?.pageController?(self, lazyLoadViewController: vc, withInfo: info)
            initializedIndex = kSSUndefinedIndex
        }
        
        if preloadPolicy == .never {
            return
        }
        
        // 根据 preloadPolicy 预加载控制器
        let length = preloadPolicy.rawValue
        
        var start: Int = 0
        var end = childControllersCount - 1
        if index > length {
            start = index - length
        }
        if childControllersCount - 1 > length + index {
            end = index + length
        }
        
        for i in start...end {
            if self.memCache.object(forKey: NSNumber(value: i)) == nil && self.displayVC[i] == nil {
                self.ss_addViewControllerAtIndex(i)
                self.ss_postAddToSuperViewNotificationWithIndex(i)
            }
        }
        _selectIndex = index
    }
    
    //MARK: - Data source
    func initializeViewControllerAtIndex(_ index: Int) -> UIViewController? {
        
        if let vc = self.dataSource?.pageController?(self, viewControllerAtIndex: index) {
            return vc
        }
        
        if let classType = viewControllerClasses?[index] {
            return classType.init()
        }
        return nil
    }
    
    //MARK: - Private Methods
    fileprivate func ss_resetScrollView() {
        if let scrollView = self.scrollView {
            scrollView.removeFromSuperview()
        }
        self.ss_addScrollView()
        self.ss_addViewControllerAtIndex(self.selectIndex)
        currentViewController = displayVC[_selectIndex]
    }
    
    fileprivate func ss_clearDatas() {
        controllerCount = kSSControllerCountUndefined
        hasInited = false
        let maxIndex = (self.childControllersCount - 1 > 0) ? self.childControllersCount - 1 : 0
        _selectIndex = (selectIndex < childControllersCount ? selectIndex : maxIndex)
        
        let preProgressWidth = progressWidth;
        if preProgressWidth > 0 {
            self.progressWidth = preProgressWidth
        }
        
        for vc in displayVC.values {
            vc.view.removeFromSuperview()
            vc.willMove(toParent: nil)
            vc.removeFromParent()
        }
        
        memoryWarningCount = 0
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ss_growCachePolicyAfterMemoryWarning), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ss_growCachePolicyToHigh), object: nil)
        currentViewController = nil
        posRecords.removeAll()
        backgroundCache.removeAll()
        displayVC.removeAll()
    }
    
    // 当子控制器init完成时发送通知
    fileprivate func ss_postAddToSuperViewNotificationWithIndex(_ index: Int) {
        guard postNotification else {
            return
        }
        let info = ["index": index, "title": self.titleAtIndex(index)] as [String : Any]
        NotificationCenter.default.post(name: NSNotification.Name.SSControllerDidAddToSuperViewNotification, object: self, userInfo: info)
    }
    
    // 当子控制器完全展示在user面前时发送通知
    fileprivate func ss_postFullyDisplayedNotificationWithCurrentIndex(_ index: Int) {
        guard postNotification else {
            return
        }
        let info = ["index": index, "title": self.titleAtIndex(index)] as [String : Any]
        NotificationCenter.default.post(name: NSNotification.Name.SSControllerDidFullyDisplayedNotification, object: self, userInfo: info)
    }
    
    fileprivate func ss_setup() {
        self.dataSource = self
        self.delegate = self
        cache_setup()
    }
    
    fileprivate func ss_calculateSize() {
        
        guard let menuFrame = self.dataSource?.pageController(self, preferredFrameForMenuView: self.menuView) else { return }
        self.menuViewFrame = menuFrame
        
        guard let contentFrame = self.dataSource?.pageController(self, preferredFrameForContentView: self.scrollView) else { return  }
        self.contentViewFrame = contentFrame
        childViewFrames.removeAll()
        for i in 0..<childControllersCount {
            childViewFrames.append(CGRect(x: CGFloat(i) * contentFrame.size.width, y: 0, width: contentFrame.size.width, height: contentFrame.size.height))
        }
    }
    
    fileprivate func ss_addScrollView() {
        let scrollView = SSPageScrollView();
        scrollView.scrollsToTop = false
        scrollView.isPagingEnabled = true
        scrollView.backgroundColor = UIColor.white
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = self.bounces;
        scrollView.isScrollEnabled = self.scrollEnable;
        if #available(iOS 11, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        }
        if let parentContentView = self.dataSource?.pageController?(self, preferredParentViewForContentView: scrollView) {
            parentContentView.insertSubview(scrollView, at: 0)
        }else {
            self.getHorizontalScrollViewSuperView().insertSubview(scrollView, at: 0)
        }
        self.scrollView = scrollView;
        
        if let nav = self.navigationController {
            if let gestureRecognizers = scrollView.gestureRecognizers, let interactivePopGesture = nav.interactivePopGestureRecognizer {
                for gesture in gestureRecognizers {
                    gesture.require(toFail: interactivePopGesture)
                }
            }
            
        }
    }
    
    fileprivate func ss_addMenuView() {
        let menuView = SSMenuView()
        menuView.delegate = self
        menuView.dataSource = self
        self.ss_initMenuViewCustomProperty(menuView)
        self.menuView = menuView
    }
    
    
    func titleAtIndex(_ index: Int) -> String {
        
        if let title = self.dataSource?.pageController?(self, titleAtIndex: index) {
            return title
        }
        
        if let titles = self.titles {
            if titles.count > index {
                return titles[index]
            }
        }
        
        return ""
    }
    
    fileprivate func ss_initMenuViewCustomProperty(_ menuView: SSMenuView) -> Void {
        menuView.style = self.menuViewStyle
        menuView.layoutMode = self.menuViewLayoutMode
        menuView.progressHeight = self.progressHeight
        if let menuViewContentMargin = self.menuViewContentMargin {
            menuView.contentMargin = menuViewContentMargin
        }
        if let progressViewBottomSpace = self.progressViewBottomSpace {
            menuView.progressViewBottomSpace = progressViewBottomSpace
        }
        if let progressViewIsNaughty = self.progressViewIsNaughty {
            menuView.progressViewIsNaughty = progressViewIsNaughty
        }
        menuView.progressWidths = self.progressViewWidths
        menuView.progressViewCornerRadius = self.progressViewCornerRadius
        menuView.showOnNavigationBar = self.showOnNavigationBar
        
        if let titleFontName = self.titleFontName {
            menuView.fontName = titleFontName
        }
        
        if let titleFontName = self.titleSelectFontName {
            menuView.titleSelectFontName = titleFontName
        }else{
            menuView.titleSelectFontName = self.titleFontName;
        }
        
        if let progressColor = self.progressColor {
            menuView.lineColor = progressColor
        }
        
        if let progressImage = self.progressImage {
            menuView.progressImage = progressImage
        }
        
        if (self.showOnNavigationBar && self.navigationController?.navigationBar != nil) {
            self.navigationItem.titleView = menuView;
        } else {
            if let parentView = self.dataSource?.pageController?(self, preferredParentViewForMenu: menuView) {
                parentView.addSubview(menuView)
            }else {
                self.getMenuSuperView().addSubview(menuView)
            }
        }
    }
    
    fileprivate func ss_layoutChildViewControllers() {
        
        let currentPage = Int(self.scrollView!.contentOffset.x / contentViewFrame.size.width)
        
        let length = preloadPolicy.rawValue
        let left = currentPage - length - 1
        let right = currentPage + length + 1
        for i in 0..<childControllersCount {
            let vc = displayVC[i]
            if i < childViewFrames.count {
                let frame = childViewFrames[i]
                if vc == nil {
                    if self.ss_isInScreen(frame) {
                        self.ss_initializedControllerWithIndexIfNeeded(i)
                    }
                }else {
                    if (i <= left || i >= right) {
                        if !self.ss_isInScreen(frame) {
                            self.ss_removeViewController(vc!, atIndex: i)
                        }
                    }
                }
            }
        }
    }
    
    // 创建或从缓存中获取控制器并添加到视图上
    fileprivate func ss_initializedControllerWithIndexIfNeeded(_ index: Int) {
        // 先从 cache 中取
        if let vc = self.memCache.object(forKey: NSNumber(value: index)) {
            // cache 中存在，添加到 scrollView 上，并放入display
            self.ss_addCachedViewController(vc, atIndex: index)
        }else {
            // cache 中也不存在，创建并添加到display
            self.ss_addViewControllerAtIndex(index)
        }
        self.ss_postAddToSuperViewNotificationWithIndex(index)
    }
    
    fileprivate func ss_addCachedViewController(_ viewController: UIViewController, atIndex index: Int) {
        self.addChild(viewController)
        viewController.view.frame = childViewFrames[index]
        viewController.didMove(toParent: self)
        scrollView?.addSubview(viewController.view)
        self.willEnterController(viewController, atIndex: index)
        displayVC[index] = viewController
    }
    // 创建并添加子控制器
    fileprivate func ss_addViewControllerAtIndex(_ index: Int) {
        initializedIndex = index
        if let viewController = self.initializeViewControllerAtIndex(index) {
            if let values = self.values, let keys = self.keys {
                if values.count == childControllersCount && keys.count == childControllersCount {
                    if index < values.count && index < keys.count {
                        viewController.setValue(values[index], forKey: keys[index])
                    }
                }
            }
            
            self.addChild(viewController)
            if index < childViewFrames.count {
                viewController.view.frame = childViewFrames[index]
            }else {
                viewController.view.frame = self.view.frame
            }
            viewController.didMove(toParent: self)
            scrollView?.addSubview(viewController.view)
            self.willEnterController(viewController, atIndex: index)
            displayVC[index] = viewController
            
            self.ss_backToPositionIfNeeded(controller: viewController, atIndex: index)
        }
    }
    
    // 移除控制器，且从display中移除
    fileprivate func ss_removeViewController(_ viewController: UIViewController, atIndex index: Int) {
        self.ss_rememberPositionIfNeeded(controller: viewController, atIndex: index)
        viewController.view.removeFromSuperview()
        viewController.willMove(toParent: nil)
        viewController.removeFromParent()
        displayVC.removeValue(forKey: index)
        
        // 放入缓存
        if cachePolicy == .disabled {
            return
        }
        if self.memCache.object(forKey: NSNumber(value: index)) == nil {
            self.willCachedController(viewController, atIndex: index)
            self.memCache.setObject(viewController, forKey: NSNumber(value: index))
        }
    }
    
    fileprivate func ss_backToPositionIfNeeded(controller: UIViewController, atIndex index: Int) {
        
        if self.memCache.object(forKey: NSNumber(value: index)) != nil {
            return
        }
        
        if let scrollView = self.ss_isKindOfScrollViewController(controller) {
            
            if let pointValue = posRecords[index] {
                scrollView.setContentOffset(pointValue, animated: false)
            }
        }
    }
    
    fileprivate func ss_rememberPositionIfNeeded(controller: UIViewController, atIndex index: Int) {
        
        if let scrollView = self.ss_isKindOfScrollViewController(controller) {
            
            let pos = scrollView.contentOffset
            
            self.posRecords[index] = pos
        }
    }
    
    fileprivate func ss_isKindOfScrollViewController(_ controller: UIViewController) -> UIScrollView? {
        var scrollView: UIScrollView?
        if controller.view is UIScrollView {
            // Controller的view是scrollView的子类(UITableViewController/UIViewController替换view为scrollView)
            scrollView = (controller.view as! UIScrollView)
            
        }else {
            if controller.view.subviews.count>=1 {
                // Controller的view的subViews[0]存在且是scrollView的子类，并且frame等与view得frame(UICollectionViewController/UIViewController添加UIScrollView)
                if let view = controller.view.subviews.first as? UIScrollView {
                    scrollView = view
                }
            }
        }
        return scrollView
    }
    
    fileprivate func ss_isInScreen(_ frame: CGRect) -> Bool {
        guard let scrollView = self.scrollView else { return false }
        let x = frame.origin.x
        let screeenWidth = scrollView.frame.size.width
        let contentOffsetX = scrollView.contentOffset.x
        if (frame.maxX > contentOffsetX) && (x - contentOffsetX < screeenWidth) {
            return true
        }
        return false
    }
    
    fileprivate func ss_resetMenuView() {
        if let menuView = self.menuView {
            self.ss_initMenuViewCustomProperty(menuView)
            menuView.reload()
            if !menuView.isUserInteractionEnabled {
                menuView.isUserInteractionEnabled = true
            }
            if _selectIndex != 0 {
                menuView.selectItemAtIndex(_selectIndex)
            }
            self.getMenuSuperView().bringSubviewToFront(menuView)
        }else {
            self.ss_addMenuView()
        }
    }
    
    @objc fileprivate func ss_growCachePolicyAfterMemoryWarning() {
        cachePolicy = .balanced
        self.perform(#selector(ss_growCachePolicyToHigh), with: nil, afterDelay: 2.0, inModes: [.common])
    }
    
    @objc fileprivate func ss_growCachePolicyToHigh() {
        cachePolicy = .high
    }
    
    //MARK: -- public methods
    func reloadData() {
        self.ss_clearDatas()
        if childControllersCount <= 0 {return}
        //这里放在scrollview前面，保证刷新时childViewFrames有数据选择任意下标时不崩溃
        self.viewDidLayoutSubviews()
        self.ss_resetScrollView()
        self.memCache.removeAllObjects()
        self.ss_resetMenuView()
        self.didEnterController(currentViewController, atIndex: _selectIndex)
    }
    
    func updateTitle(_ title: String, atIndex index: Int) {
        self.menuView?.updateTitle(title, atIndex: index, andWidth: false)
    }
    
    func updateAttributeTitle(_ title: NSAttributedString, atIndex index: Int) {
        self.menuView?.updateAttributeTitle(title, atIndex: index, andWidth: false)
    }
    
    func updateTitle(_ title: String, andWidth width: CGFloat, atIndex index: Int) {
        if var itemsWidths = self.itemsWidths, index < itemsWidths.count {
            itemsWidths[index] = width
            self.itemsWidths = itemsWidths
        }else {
            var mutableWidths = [CGFloat]()
            for i in 0..<childControllersCount {
                let itemWidth = i==index ? width : menuItemWidth
                mutableWidths.append(itemWidth)
            }
            self.itemsWidths = mutableWidths
        }
        self.menuView?.updateTitle(title, atIndex: index, andWidth: true)
    }
    
    //子类重写
    public func getHorizontalScrollViewSuperView() -> UIView {
        return self.view//默认self.view
    }
    //子类重写
    public func getMenuSuperView() -> UIView {
        return self.view;
    }
    
    //MARK: - Adjust Frame
    fileprivate func ss_adjustScrollViewFrame() {
        // While rotate at last page, set scroll frame will call `-scrollViewDidScroll:` delegate
        // It's not my expectation, so I use `_shouldNotScroll` to lock it.
        // Wait for a better solution.
        guard let scrollView = self.scrollView else { return  }
        shouldNotScroll = true
        let oldContentOffsetX = scrollView.contentOffset.x
        let contentWidth = scrollView.contentSize.width
        scrollView.frame = contentViewFrame
        scrollView.contentSize = CGSize(width: CGFloat(childControllersCount) * contentViewFrame.size.width, height: 0)
        let xContentOffset = contentWidth == 0 ? CGFloat(_selectIndex) * contentViewFrame.size.width : oldContentOffsetX / contentWidth * CGFloat(childControllersCount) * contentViewFrame.size.width
        scrollView.contentOffset = CGPoint(x: xContentOffset, y: 0)
        shouldNotScroll = false
    }
    
    fileprivate func ss_adjustDisplayingViewControllersFrame() {
        for (index, vc) in displayVC {
            if index < childViewFrames.count {
                vc.view.frame = childViewFrames[index]
            }
        }
    }
    
    fileprivate func ss_adjustMenuViewFrame() {
        guard let menuView = self.menuView else { return }
        let oriWidth = menuView.frame.size.width
        menuView.frame = menuViewFrame
        menuView.resetFrames()
        if oriWidth != menuView.frame.size.width {
            menuView.refreshContenOffset()
        }
    }
    
    fileprivate func ss_calculateItemWithAtIndex(_ index: Int) -> CGFloat {
        let title = self.titleAtIndex(index)
        
        var titleFont: UIFont!
        
        if let titleFontName = self.titleFontName {
            titleFont = UIFont(name: titleFontName, size: titleSizeSelected)
        }else {
            titleFont = UIFont.boldSystemFont(ofSize: titleSizeSelected)
        }
        
        let ocTitle = title as NSString
        
        let itemWidth = ocTitle.boundingRect(with: .zero, options: .usesFontLeading, attributes: [.font : titleFont!], context: nil).size.width
        
        return CGFloat(ceilf(Float(itemWidth)))
    }
    
    fileprivate func ss_delaySelectIndexIfNeeded() {
        //        if (_markedSelectIndex != kJWUndefinedIndex) {
        //            self.selectIndex = (int)_markedSelectIndex;
        //        }
    }
}

extension SSPageController: SSPageControllerDataSource, SSPageControllerDelegate {
    func pageController(_ pageController: SSPageController, preferredFrameForContentView contentView: SSPageScrollView?) -> CGRect {
        assert(false, "子类必须实现")
        return .zero
    }
    
    func pageController(_ pageController: SSPageController, preferredFrameForMenuView menuView: SSMenuView?) -> CGRect {
        assert(false, "子类必须实现")
        return .zero
    }
    
}

extension SSPageController: SSMenuViewDataSource, SSMenuViewDelegate {
    func menuView(_ menu: SSMenuView, didSelesctedIndex index: Int, currentIndex: Int) {
        if !hasInited {return}
        
        if currentIndex == index {
            self.delegate?.pageController?(self, didClickIndexAgainWithIndex: index)
            return
        }
        
        _selectIndex = index
        
        startDragging = false
        
        
        if fabs(Double(currentIndex) - Double(index)) >= 2.0 {
            let transition = CATransition()
            transition.type = .push //可更改为其他方式
            transition.subtype = .fromRight //可更改为其他方式
            self.scrollView?.layer.add(transition, forKey: kCATransition)
            self.scrollView?.setContentOffset(CGPoint(x: contentViewFrame.size.width * CGFloat(index), y: 0), animated: false)
        }else{
            self.scrollView?.setContentOffset(CGPoint(x: contentViewFrame.size.width * CGFloat(index), y: 0), animated: pageAnimatable)
        }
        
        if pageAnimatable {return}
        
        if let currentViewController = self.displayVC[currentIndex] {
            self.ss_removeViewController(currentViewController, atIndex: currentIndex)
        }
        
        self.ss_layoutChildViewControllers()
        self.didEnterController(self, atIndex: index)
        
        //        self.setNeedsStatusBarAppearanceUpdate()//根据子控制器更新状态栏
    }
    func menuView(_ menu: SSMenuView, widthForItemAtIndex index: Int) -> CGFloat {
        if self.automaticallyCalculatesItemWidths {
            return (self.ss_calculateItemWithAtIndex(index) + 20)
        }
        
        if let itemsWidths = itemsWidths, itemsWidths.count == childControllersCount {
            return itemsWidths[index]
        }
        
        return self.menuItemWidth;
    }
    func menuView(_ menu: SSMenuView, itemMarginAtIndex index: Int) -> CGFloat {
        if let itemsMargins = itemsMargins, itemsMargins.count == self.childControllersCount + 1 {
            return itemsMargins[index]
        }
        return self.itemMargin ?? 0
    }
    func menuView(_ menu: SSMenuView, titleSizeForState state: SSMenuItemState, atIndex index: Int) -> CGFloat {
        switch state {
        case .selected:
            return titleSizeSelected
        default:
            return titleSizeNormal
        }
    }
    func menuView(_ menu: SSMenuView, titleColorForState state: SSMenuItemState, atIndex index: Int) -> UIColor {
        switch state {
        case .selected:
            return titleColorSelected
        default:
            return titleColorNormal
        }
    }
    
    func numbersOfTitlesInMenuView(_ menu: SSMenuView) -> Int {
        return self.childControllersCount
    }
    func menuView(_ menu: SSMenuView, titleAtIndex index: Int) -> String {
        return self.titleAtIndex(index)
    }
}

extension SSPageController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !(scrollView is SSPageScrollView) {
            return
        }
        if shouldNotScroll || !hasInited {
            return
        }
        self.ss_layoutChildViewControllers()
        if startDragging {
            var contentOffsetX = scrollView.contentOffset.x
            if contentOffsetX < 0 {
                contentOffsetX = 0
            }
            if contentOffsetX > scrollView.contentSize.width - contentViewFrame.size.width {
                contentOffsetX = scrollView.contentSize.width - contentViewFrame.size.width
            }
            let rate = contentOffsetX / contentViewFrame.size.width
            self.menuView?.slideMenuAtProgress(rate)
        }
        // Fix scrollView.contentOffset.y -> (-20) unexpectedly.
        if (scrollView.contentOffset.y == 0) {return}
        var contentOffset = scrollView.contentOffset
        contentOffset.y = 0.0;
        scrollView.contentOffset = contentOffset;
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if !(scrollView is SSPageScrollView) {
            return
        }
        startDragging = true
        self.menuView?.isUserInteractionEnabled = false
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if !(scrollView is SSPageScrollView) {
            return
        }
        self.menuView?.isUserInteractionEnabled = true
        _selectIndex = Int(scrollView.contentOffset.x / contentViewFrame.size.width)
        currentViewController = displayVC[_selectIndex]
        self.didEnterController(currentViewController, atIndex: _selectIndex)
        self.menuView?.deselectedItemsIfNeeded()
        
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if !(scrollView is SSPageScrollView) {
            return
        }
        currentViewController = displayVC[_selectIndex]
        self.didEnterController(currentViewController, atIndex: _selectIndex)
        self.menuView?.deselectedItemsIfNeeded()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !(scrollView is SSPageScrollView) {
            return
        }
        if !decelerate {
            self.menuView?.isUserInteractionEnabled = true
            let rate = targetX / contentViewFrame.size.width
            self.menuView?.slideMenuAtProgress(rate)
            self.menuView?.deselectedItemsIfNeeded()
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if !(scrollView is SSPageScrollView) {
            return
        }
        targetX = targetContentOffset.pointee.x
    }
    
    
}

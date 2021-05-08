//
//  SSMenuView.swift
//
//
//  Created by Shine on 2020/2/18.
//  Copyright © 2020 Shine. All rights reserved.
//

import UIKit

let SSUNDEFINED_VALUE: CGFloat = -1.0
let SSMENUITEM_TAG_OFFSET: Int = 6250
let SSBADGEVIEW_TAG_OFFSET: Int = 1212

enum SSMenuViewStyle {
    case styleDefault // 默认
    case styleLine // 带下划线(若要选中字体大小不变，设置选中和非选中大小一样即可)
    case styleTriangle // 三角形 (progressHeight 为三角形的高, progressWidths 为底边长)
    case styleFlood // 涌入效果 (填充)
    case styleFloodHollow // 涌入效果 (空心的)
    case styleSegmented // 涌入带边框,即网易新闻选项卡
    case styleCustomSegmented //自定义Segment样式
//    case styleImage   // 带下划线为图片
}

// 原先基础上添加了几个方便布局的枚举，更多布局格式可以通过设置 `itemsMargins` 属性来自定义
// 以下布局均只在 item 个数较少的情况下生效，即无法滚动 MenuView 时.
enum SSMenuViewLayoutMode {
    case scatter // 默认的布局模式, item 会均匀分布在屏幕上，呈分散状
    case left // Item 紧靠屏幕左侧
    case right // Item 紧靠屏幕右侧
    case center // Item 紧挨且居中分布
}

protocol SSMenuViewDelegate: NSObjectProtocol {
    func menuView(_ menu: SSMenuView, shouldSelesctedIndex index: Int) -> Bool
    func menuView(_ menu: SSMenuView, didSelesctedIndex index: Int, currentIndex: Int)
    func menuView(_ menu: SSMenuView, widthForItemAtIndex index: Int) -> CGFloat
    func menuView(_ menu: SSMenuView, itemMarginAtIndex index: Int) -> CGFloat
    func menuView(_ menu: SSMenuView, titleSizeForState state: SSMenuItemState, atIndex index: Int) -> CGFloat
    func menuView(_ menu: SSMenuView, titleColorForState state: SSMenuItemState, atIndex index: Int) -> UIColor
    func menuView(_ menu: SSMenuView, didLayoutItemFrame menuItem: SSMenuItem, atIndex index: Int)
}

extension SSMenuViewDelegate {
    func menuView(_ menu: SSMenuView, shouldSelesctedIndex index: Int) -> Bool {
        return true
    }
    func menuView(_ menu: SSMenuView, didSelesctedIndex index: Int, currentIndex: Int) {
        
    }
    func menuView(_ menu: SSMenuView, widthForItemAtIndex index: Int) -> CGFloat {
        return 60.0//默认item width为60
    }
    func menuView(_ menu: SSMenuView, itemMarginAtIndex index: Int) -> CGFloat {
        return 0
    }
    func menuView(_ menu: SSMenuView, titleSizeForState state: SSMenuItemState, atIndex index: Int) -> CGFloat {
        return 15.0
    }
    func menuView(_ menu: SSMenuView, titleColorForState state: SSMenuItemState, atIndex index: Int) -> UIColor {
        return UIColor.black
    }
    func menuView(_ menu: SSMenuView, didLayoutItemFrame menuItem: SSMenuItem, atIndex index: Int) {
        
    }
}

protocol SSMenuViewDataSource: NSObjectProtocol {
    func numbersOfTitlesInMenuView(_ menu: SSMenuView) -> Int
    func menuView(_ menu: SSMenuView, titleAtIndex index: Int) -> String
    func menuView(_ menu: SSMenuView, badgeViewAtIndex index: Int) -> UIView?
    func menuView(_ menu: SSMenuView, initialMenuItem menuItem: SSMenuItem, atIndex index: Int) -> SSMenuItem?
}

extension SSMenuViewDataSource {
    func menuView(_ menu: SSMenuView, badgeViewAtIndex index: Int) -> UIView? {
        return nil
    }
    func menuView(_ menu: SSMenuView, initialMenuItem menuItem: SSMenuItem, atIndex index: Int) -> SSMenuItem? {
        return nil
    }
}

class SSMenuView: UIView {
    
    var progressWidths: [CGFloat]? {
        didSet {
            if self.progressView?.superview == nil {
                return
            }
            self.resetFramesFromIndex(0)
        }
    }
    weak var progressView: SSMenuProgressView?
    
    var progressHeight = SSUNDEFINED_VALUE
    var progressHeightValue: CGFloat {
        switch (self.style) {
        case .styleLine,
             .styleTriangle:
//             .styleImage:
            return progressHeight == SSUNDEFINED_VALUE ? 3.0 : progressHeight
        case .styleFlood,
             .styleSegmented,
             .styleFloodHollow:
            let defaultHeight: Float = Float(self.frame.size.height * 0.8)
            
            return progressHeight == SSUNDEFINED_VALUE ? CGFloat(ceilf(defaultHeight)) : progressHeight
        default:
            return progressHeight;
        }
    }
    
    
    var style: SSMenuViewStyle = .styleDefault
    var layoutMode: SSMenuViewLayoutMode = .scatter
    var contentMargin: CGFloat = 0
    var lineColor: UIColor = UIColor.black {
        didSet {
            self.progressView?.color = lineColor.cgColor
        }
    }
    
    var progressViewBottomSpace: CGFloat = 0
    weak var delegate: SSMenuViewDelegate?
    weak var dataSource: SSMenuViewDataSource?
    weak var leftView: UIView?
    weak var rightView: UIView?
    /** progressImage优先于lineColor */
    var progressImage:UIImage?
    
    lazy var menuViewArray: [SSMenuItem] = {
        return [SSMenuItem]()
    }()
    
    var fontName: String?
    var titleSelectFontName: String?
    weak var scrollView: UIScrollView?
    
    //进度条的速度因数，默认为 15，越小越快， 大于 0
    var speedFactor: CGFloat = 15.0
    
    var progressViewCornerRadiusValue = SSUNDEFINED_VALUE
    
    var progressViewCornerRadius: CGFloat {
        
        set {
            progressViewCornerRadiusValue = newValue
            if let progressView = progressView {
                progressView.cornerRadiusProgress = newValue
            }
        }
        
        get {
            return progressViewCornerRadiusValue != SSUNDEFINED_VALUE ? progressViewCornerRadiusValue : self.progressHeightValue/2.0
        }
    }
    
    var progressViewIsNaughty = false {
        didSet {
            self.progressView?.naughty = progressViewIsNaughty;
        }
    }
    var showOnNavigationBar = false
    
    weak var selItem: SSMenuItem?
    var frames = [CGRect]()
    var selectIndex = 0
    var titlesCount: Int {
        get {
            return self.dataSource?.numbersOfTitlesInMenuView(self) ?? 0
        }
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        
        if scrollView != nil {
            return
        }
        
        addScrollView()
        addItems()
        makeStyle()
        addBadgeViews()
        resetSelectionIfNeeded()
    }
    
}

//MARK: Private Methods
private extension SSMenuView {
    
    func addScrollView() {
        
        let width = self.frame.size.width - self.contentMargin * 2.0
        let height = self.frame.size.height
        let frame = CGRect(x: contentMargin, y: 0, width: width, height: height)
        
        let scrollView = UIScrollView(frame: frame)
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = UIColor.clear
        scrollView.scrollsToTop = false
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        }
        self.addSubview(scrollView)
        self.scrollView = scrollView;
    }
    
    func resetSelectionIfNeeded() {
        if self.selectIndex == 0 {
            return
        }
        self.selectItemAtIndex(selectIndex)
    }
    
    func itemMarginAtIndex(_ index: Int) -> CGFloat {
        return self.delegate?.menuView(self, itemMarginAtIndex: index) ?? 0;
    }
    
    func resetFramesFromIndex(_ index: Int) {
        self.frames.removeAll()
        self.calculateItemFrames()
        for i in 0..<self.titlesCount {
            self.resetItemFrame(i)
            self.resetBadgeFrame(index: i)
        }
        if self.progressView?.superview == nil {return}
        
        self.progressView?.frame = self.calculateProgressViewFrame()
        self.progressView?.cornerRadiusProgress = self.progressViewCornerRadius
        self.progressView?.itemFrames = self.convertProgressWidthsToFrames()
        self.progressView?.setNeedsDisplay()
    }
    
    func resetItemFrame(_ index: Int) {
        if (self.frames.count<=index) {//防止数组越界
            return;
        }
        if let item = self.viewWithTag(index + SSMENUITEM_TAG_OFFSET) as? SSMenuItem {
            let frame = self.frames[index]
            item.frame = frame
            self.delegate?.menuView(self, didLayoutItemFrame: item, atIndex: index)
        }
    }
    
    func resetBadgeFrame(index: Int) {
        if (self.frames.count<=index) {//防止数组越界
            return;
        }
        
        let frame = self.frames[index]
        if let badgeView = self.scrollView?.viewWithTag(SSBADGEVIEW_TAG_OFFSET + index) {
            if var badgeFrame = self.badgeViewAtIndex(index)?.frame {
                badgeFrame.origin.x += frame.origin.x
                badgeView.frame = badgeFrame
            }
            
        }
    }
    
    // 计算所有item的frame值，主要是为了适配所有item的宽度之和小于屏幕宽的情况
    // 这里与后面的 `-addItems` 做了重复的操作，并不是很合理
    func calculateItemFrames() {
        var contentWidth:CGFloat = itemMarginAtIndex(0)
        
        for i in 0..<self.titlesCount {
            let itemW: CGFloat = self.delegate?.menuView(self, widthForItemAtIndex: i) ?? 60.0
            let frame = CGRect(x: contentWidth, y: 0, width: itemW, height: self.frame.size.height)
            self.frames.append(frame)
            contentWidth += itemW + itemMarginAtIndex(i+1)
        }
        
        guard let scrollView = self.scrollView else { return  }
        
        // 如果总宽度小于屏幕宽,重新计算frame,为item间添加间距
        if contentWidth < scrollView.frame.size.width {
            let distance = scrollView.frame.size.width - contentWidth;
            
            let shiftDis: ((Int) -> CGFloat)?
            
            switch layoutMode {
            case .scatter:
                let gap = distance / CGFloat(self.titlesCount + 1)
                shiftDis = { (index) -> CGFloat in
                    return gap * CGFloat((index + 1))
                }
            case .left:
                shiftDis = { (index) -> CGFloat in
                    return 0.0
                }
            case .right:
                shiftDis = { (index) -> CGFloat in
                    return distance
                }
            case .center:
                shiftDis = { (index) -> CGFloat in
                    return distance/2.0
                }
            }
            
            for i in 0..<self.frames.count {
                var frame = self.frames[i]
                
                if let offset = shiftDis?(i) {
                    frame.origin.x += offset
                }
                
                self.frames[i] = frame
            }
            
            contentWidth = scrollView.frame.size.width
        }
        scrollView.contentSize = CGSize(width: contentWidth, height: self.frame.size.height)
    }
    
    func addItems() {
        calculateItemFrames()
        for i in 0..<self.titlesCount {
            let frame = self.frames[i]
            var item = SSMenuItem(frame: frame)
            item.tag = SSMENUITEM_TAG_OFFSET + i
            item.delegate = self
            item.text = self.dataSource?.menuView(self, titleAtIndex: i)
            item.textAlignment = .center
            item.isUserInteractionEnabled = true
            item.backgroundColor = UIColor.clear
            item.normalSize = self.delegate?.menuView(self, titleSizeForState: .normal, atIndex: i) ?? 15.0
            item.selectedSize = self.delegate?.menuView(self, titleSizeForState: .selected, atIndex: i) ?? 15.0
            item.normalColor = self.delegate?.menuView(self, titleColorForState: .normal, atIndex: i) ?? UIColor.black
            item.selectedColor = self.delegate?.menuView(self, titleColorForState: .selected, atIndex: i) ?? UIColor.black
            item.speedFactor = self.speedFactor
            
            if self.fontName != nil {
                item.font = UIFont(name: self.fontName!, size: item.normalSize)
            }else {
                item.font = UIFont.systemFont(ofSize: item.normalSize)
            }
            
            if let customItem = self.dataSource?.menuView(self, initialMenuItem: item, atIndex: i) {
                item = customItem
            }
            if i == 0 {
                item.setSelected(selected: true, animation: false)
                if let titleSelectFontName = self.titleSelectFontName {
                    item.font = UIFont(name: titleSelectFontName, size: item.selectedSize)
                }
                self.selItem = item
            } else {
                item.setSelected(selected: false, animation: false)
            }
            self.menuViewArray.append(item)
            self.scrollView?.addSubview(item)
        }
    }
    
    func calculateProgressViewFrame() -> CGRect {
        
        guard let scrollView = self.scrollView else { return .zero }
        
        switch (self.style) {
        case .styleDefault,
             .styleCustomSegmented:
            return .zero
        case .styleLine,
             .styleTriangle:
            return CGRect(x: 0, y: self.frame.size.height - self.progressHeightValue - self.progressViewBottomSpace, width: scrollView.contentSize.width, height: self.progressHeightValue)
        case .styleFloodHollow,
             .styleSegmented,
             .styleFlood:
            return CGRect(x: 0, y: (self.frame.size.height - self.progressHeightValue) / 2, width: scrollView.contentSize.width, height: self.progressHeightValue)
//        case .styleImage:
//            return CGRect(x: 0, y: self.frame.size.height - self.progressHeightValue - self.progressViewBottomSpace, width: scrollView.contentSize.width, height: self.progressHeightValue)
        }
    }
    
    func makeStyle() {
        let frame: CGRect = self.calculateProgressViewFrame()
        if frame.equalTo(.zero) {
            return
        }
        
        
        let pView = SSMenuProgressView(frame: frame)
        pView.itemFrames = self.convertProgressWidthsToFrames()
        pView.color = self.lineColor.cgColor
        pView.isTriangle = (self.style == .styleTriangle)
        pView.hasBorder = (self.style == .styleSegmented)
        pView.hollow = (self.style == .styleFloodHollow)
//        pView.hasImage = (self.style == .styleImage)
        pView.cornerRadiusProgress = self.progressViewCornerRadius
        pView.naughty = self.progressViewIsNaughty
        pView.speedFactor = self.speedFactor
        pView.backgroundColor = UIColor.clear
        pView.progressImage = self.progressImage
        self.progressView = pView
        self.scrollView?.insertSubview(pView, at: 0)
    }
    
    func convertProgressWidthsToFrames() -> [CGRect] {
        if self.frames.count <= 0 {
            assert(false, "BUUUUUUUG...SHOULDN'T COME HERE!!")
        }
        
        guard let progressWidths = self.progressWidths else {
            return self.frames
        }
        
        if progressWidths.count < self.titlesCount {
            return self.frames
        }
        
        var progressFrames = [CGRect]()
        
        var count = self.frames.count
        if progressWidths.count >= self.frames.count {
            count = progressWidths.count
        }
        
        for i in 0..<count {
            let itemFrame = self.frames[i]
            let progressWidth = progressWidths[i]
            let x: CGFloat = itemFrame.origin.x + (itemFrame.size.width - progressWidth)/2.0
            let progressFrame = CGRect(x: x, y: itemFrame.origin.y, width: progressWidth, height: 0)
            progressFrames.append(progressFrame)
        }
        
        return progressFrames;
    }
    
    func addBadgeViews() {
        for i in 0..<self.titlesCount {
            self.addBadgeViewAtIndex(i)
        }
    }
    func addBadgeViewAtIndex(_ index: Int) {
        let badgeView = self .badgeViewAtIndex(index);
        if let badgeView = badgeView {
            self.scrollView?.addSubview(badgeView)
        }
    }
    
    func badgeViewAtIndex(_ index: Int) -> UIView? {
        
        let badgeView = self.dataSource?.menuView(self, badgeViewAtIndex: index)
        badgeView?.tag = index + SSBADGEVIEW_TAG_OFFSET
        
        return badgeView
    }
    
}

extension SSMenuView: SSMenuItemDelegate {
    func didPressedMenuItem(_ menuItem: SSMenuItem) {
        
        if (self.selItem == menuItem) {return;}
        
        if let should = self.delegate?.menuView(self, shouldSelesctedIndex: menuItem.tag - SSMENUITEM_TAG_OFFSET) {
            if !should {
                return
            }
        }
        
        let progress = menuItem.tag - SSMENUITEM_TAG_OFFSET;
        self.progressView?.moveToPostion(pos: progress)
        
        guard let selItem = self.selItem else { return  }
        
        let currentIndex = selItem.tag - SSMENUITEM_TAG_OFFSET;
        
        self.delegate?.menuView(self, didSelesctedIndex: menuItem.tag - SSMENUITEM_TAG_OFFSET, currentIndex: currentIndex)
        selItem.setSelected(selected: false, animation: true)
        if let fontName = self.fontName {
            selItem.font = UIFont(name: fontName, size: self.selItem!.normalSize)
        }
        menuItem.setSelected(selected: true, animation: true)
        if let titleSelectFontName = self.titleSelectFontName {
            menuItem.font = UIFont(name: titleSelectFontName, size: menuItem.selectedSize)
        }
        
        self.selItem = menuItem;
        
        let delay: TimeInterval = self.style == .styleDefault ? 0 : 0.3
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.refreshContenOffset()
        }
        
    }
}

//MARK: Public Methods
extension SSMenuView {
    
    func itemAtIndex(_ index: Int) -> SSMenuItem? {
        return self.viewWithTag(index + SSMENUITEM_TAG_OFFSET) as? SSMenuItem
    }
    
    func reload() {
        self.frames.removeAll()
        self.progressView?.removeFromSuperview()
        self.menuViewArray.removeAll()
        if let subviews = self.scrollView?.subviews {
            for subView in subviews {
                subView.removeFromSuperview()
            }
        }
        self.addItems()
        self.makeStyle()
        self.addBadgeViews()
    }
    
    func resetFrames() {
        var frame = self.bounds
        if let rightView = self.rightView {
            var rightFrame = rightView.frame
            rightFrame.origin.x = frame.size.width - rightFrame.size.width
            self.rightView?.frame = rightFrame
            frame.size.width -= rightFrame.size.width
        }
        
        if let leftView = self.leftView {
            var leftFrame = leftView.frame
            leftFrame.origin.x = 0;
            self.leftView?.frame = leftFrame;
            frame.origin.x += leftFrame.size.width;
            frame.size.width -= leftFrame.size.width;
        }
        
        frame.origin.x += self.contentMargin
        frame.size.width -= self.contentMargin * 2
        self.scrollView?.frame = frame
        self.resetFramesFromIndex(0)
    }
    
    func slideMenuAtProgress(_ progress: CGFloat) {
        if let progressView = self.progressView {
            progressView.progress = progress
        }
        
        let tag = Int(progress) + SSMENUITEM_TAG_OFFSET;
        let rate = progress - CGFloat(tag) + CGFloat(SSMENUITEM_TAG_OFFSET)
        
        let currentItem = self.viewWithTag(tag) as? SSMenuItem
        
        let nextItem = self.viewWithTag(tag+1) as? SSMenuItem
        
        if rate == 0.0 {
            self.selItem?.setSelected(selected: false, animation: false)
            if let fontName = self.fontName {
                self.selItem?.font = UIFont(name: fontName, size: self.selItem!.normalSize)
            }
            self.selItem = currentItem
            self.selItem?.setSelected(selected: true, animation: false)
            if let titleSelectFontName = self.titleSelectFontName {
                self.selItem?.font = UIFont(name: titleSelectFontName, size: self.selItem!.selectedSize)
            }
            
            self.refreshContenOffset()
            return
        }
        currentItem?.rate = 1-rate
        nextItem?.rate = rate
    }
    
    func selectItemAtIndex(_ index: Int) {
        
        guard let selItem = self.selItem else { return  }
        
        let tag = index + SSMENUITEM_TAG_OFFSET;
        let currentIndex = selItem.tag - SSMENUITEM_TAG_OFFSET
        self.selectIndex = index
        if index == currentIndex {
            return
        }
        
        guard let item = self.viewWithTag(tag) as? SSMenuItem else { return  }
        selItem.setSelected(selected: false, animation: false)
        if let fontName = self.fontName {
            selItem.font = UIFont(name: fontName, size: self.selItem!.normalSize)
        }
        self.selItem = item
        item.setSelected(selected: true, animation: false)
        if let titleSelectFontName = self.titleSelectFontName {
            self.selItem?.font = UIFont(name: titleSelectFontName, size: self.selItem!.selectedSize)
        }
        self.progressView?.setProgressWithOutAnimate(progress: CGFloat(index))
        self.delegate?.menuView(self, didSelesctedIndex: index, currentIndex: currentIndex)
        
        self.refreshContenOffset()
    }
    
    func updateTitle(_ title: String, atIndex index: Int, andWidth update: Bool) {
        if (index >= self.titlesCount || index < 0) { return
        }
        
        if let item = self.viewWithTag(SSMENUITEM_TAG_OFFSET + index) as? SSMenuItem {
            item.text = title
        }
        
        if !update {
            return
        }
        
        self.resetFrames()
    }
    
    func updateAttributeTitle(_ title: NSAttributedString, atIndex index: Int, andWidth update: Bool) {
        if (index >= self.titlesCount || index < 0) { return
        }
        
        if let item = self.viewWithTag(SSMENUITEM_TAG_OFFSET + index) as? SSMenuItem {
            item.attributedText = title
        }
        
        if !update {
            return
        }
        
        self.resetFrames()
    }
    
    //更新角标视图，如要移除，在 -menuView:badgeViewAtIndex: 中返回 nil 即可
    func updateBadgeViewAtIndex(_ index: Int) {
        if let oldBadgeView = self.scrollView?.viewWithTag(SSBADGEVIEW_TAG_OFFSET + index) {
            oldBadgeView.removeFromSuperview()
        }
        self.addBadgeViewAtIndex(index)
        self.resetBadgeFrame(index: index)
        
    }
    
    /// 立即刷新 menuView 的 contentOffset，使 title 居中
    // 让选中的item位于中间
    func refreshContenOffset() {
        
        guard let selItem = self.selItem else { return  }
        guard let scrollView = self.scrollView else { return  }
        
        let frame = selItem.frame
        let itemX = frame.origin.x
        let width = scrollView.frame.size.width
        let contentSize = scrollView.contentSize
        
        if (itemX > width/2) {
            var targetX: CGFloat = 0
            if ((contentSize.width-itemX) <= width/2) {
                targetX = contentSize.width - width;
            } else {
                targetX = frame.origin.x - width/2 + frame.size.width/2;
            }
            // 应该有更好的解决方法
            if (targetX + width > contentSize.width) {
                targetX = contentSize.width - width;
            }
            scrollView.setContentOffset(CGPoint(x: targetX, y: 0), animated: true)
        } else {
            scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
        }
    }
    
    func deselectedItemsIfNeeded() {
        if let subViews = self.scrollView?.subviews {
            for subView in subViews {
                if let item = subView as? SSMenuItem, item != self.selItem {
                    item.setSelected(selected: false, animation: false)
                }
                
            }
        }
    }
    
    func adjustLineColor(_ color: UIColor?) {
        if let color = color {
            lineColor = color
        }
    }
    
}

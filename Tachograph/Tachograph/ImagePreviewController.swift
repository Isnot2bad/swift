//
//  ImagePreviewController.swift
//  Tachograph
//
//  Created by larryhou on 01/08/2017.
//  Copyright © 2017 larryhou. All rights reserved.
//

import Foundation
import UIKit

extension CGAffineTransform {
    var scaleX: CGFloat {
        return sqrt(a*a + c*c)
    }

    var scaleY: CGFloat {
        return sqrt(b*b + d*d)
    }

    var scale: (CGFloat, CGFloat) {
        return (self.scaleX, self.scaleY)
    }
}

class ImageScrollController: PageController<ImagePreviewController, CameraModel.CameraAsset>, UIGestureRecognizerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panUpdate(sender:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return UIDevice.current.orientation.isPortrait
    }

    var fractionComplete = CGFloat.nan
    var dismissAnimator: UIViewPropertyAnimator!
    @objc func panUpdate(sender: UIPanGestureRecognizer) {
        switch sender.state {
            case .began:
                dismissAnimator = UIViewPropertyAnimator(duration: 0.2, curve: .linear) { [unowned self] in
                    self.view.frame.origin.y = self.view.frame.height
                    self.view.layer.cornerRadius = 40
                }
                dismissAnimator.addCompletion { [unowned self] position in
                    if position == .end {
                        self.dismiss(animated: false, completion: nil)
                    }
                    self.fractionComplete = CGFloat.nan
                }
                dismissAnimator.pauseAnimation()
            case .changed:
                if fractionComplete.isNaN {fractionComplete = 0}

                let translation = sender.translation(in: view)
                fractionComplete += translation.y / view.frame.height
                fractionComplete = min(1, max(0, fractionComplete))
                dismissAnimator.fractionComplete = fractionComplete
                sender.setTranslation(CGPoint.zero, in: view)
            default:
                if dismissAnimator.fractionComplete <= 0.25 {
                    dismissAnimator.isReversed = true
                }
                dismissAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 1.0)
        }
    }
}

class ImagePreviewController: ImagePeekController, PageProtocol {
    static func instantiate(_ storyboard: UIStoryboard) -> PageProtocol {
        return storyboard.instantiateViewController(withIdentifier: "ImagePreviewController") as! PageProtocol
    }

    var pageAsset: Any? {
        didSet {
            if let data = self.pageAsset as? CameraModel.CameraAsset {
                self.url = data.url
                self.data = data
            }
        }
    }

    var scaleRange: (CGFloat, CGFloat) = (1.0, 3.0)
    var frameImage = CGRect()

    weak var panGesture: UIPanGestureRecognizer?

    override func viewDidLoad() {
        super.viewDidLoad()
        presentController = self
        scaleRange = (scaleRange.0, view.frame.height / image.frame.height)
        frameImage = image.frame

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchUpdate(sender:)))
        view.addGestureRecognizer(pinch)

//        let pan = UIPanGestureRecognizer(target: self, action: #selector(panUpdate(sender:)))
//        image.addGestureRecognizer(pan)
//        panGesture = pan

        let press = UILongPressGestureRecognizer(target: self, action: #selector(pressUpdate(sender:)))
        image.addGestureRecognizer(press)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        image.transform = CGAffineTransform.identity
    }

    @objc func pressUpdate(sender: UILongPressGestureRecognizer) {
        if sender.state != .began {return}
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "保存到相册", style: .default, handler: { _ in self.saveToAlbum() }))
        alertController.addAction(UIAlertAction(title: "分享", style: .default, handler: { _ in self.share() }))
        alertController.addAction(UIAlertAction(title: "删除", style: .destructive, handler: { _ in self.delete() }))
        alertController.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    var panAnimator: UIViewPropertyAnimator?

    var origin: CGPoint = CGPoint()
    @objc func panUpdate(sender: UIPanGestureRecognizer) {
        switch sender.state {
            case .began:
                origin = image.frame.origin
            case .changed:
                let offset = sender.translation(in: image.superview)
                image.frame.origin.x = origin.x + offset.x
                image.frame.origin.y = origin.y + offset.y
            case .ended:
                positionAdjust()
            default:break
        }
    }

    func positionAdjust() {
        var rect = image.superview!.convert(image.frame, to: view)
        rect.origin.x = max(min(rect.origin.x, 0), view.frame.width - rect.width)
        rect.origin.y = max(min(rect.origin.y, 0), (view.frame.height - rect.height)/2)
        rect = view.convert(rect, to: image.superview)
        let animator = UIViewPropertyAnimator(duration: 0.2, curve: .easeOut) { [unowned self] in
            self.image.frame = rect
        }
        animator.startAnimation()
    }

    func scaleAdjust(relatedUpdate: Bool = true, fitted: Bool = false) {
        scale = fitted ? scaleRange.0 : min(max(scaleRange.0, scale), scaleRange.1)

        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let animator = UIViewPropertyAnimator(duration: 0.4, dampingRatio: 0.85) { [unowned self] in
            self.image.transform = transform
        }
        if (relatedUpdate) {animator.addCompletion { _ in self.positionAdjust() }}
        animator.startAnimation()
    }

    var scale: CGFloat = 1.0
    @objc func pinchUpdate(sender: UIPinchGestureRecognizer) {
        switch sender.state {
            case .began:
                sender.scale = image.transform.scaleX
            case .changed:
                scale = sender.scale
                image.transform = CGAffineTransform(scaleX: scale, y: scale)
            case .ended:
                scaleAdjust()
            default:break
        }
    }
}

class ImagePeekController: UIViewController {
    var url: String!
    var data: CameraModel.CameraAsset?
    var index: Int = -1

    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!

    weak var presentController: UIViewController?

    override var previewActionItems: [UIPreviewActionItem] {
        var actions: [UIPreviewAction] = []
        actions.append(UIPreviewAction(title: "保存到相册", style: .default) { (_: UIPreviewAction, _: UIViewController) in
            self.saveToAlbum()
        })
        actions.append(UIPreviewAction(title: "分享", style: .default) { (_: UIPreviewAction, _: UIViewController) in
            self.share()
        })
        return actions
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        indicator.stopAnimating()

        self.image.image = nil

        let manager = AssetManager.shared
        if let location = manager.get(cacheOf: url) {
            image.image = try! UIImage(data: Data(contentsOf: location))
        } else {
            indicator.startAnimating()
            manager.load(url: url, completion: {
                self.indicator?.stopAnimating()
                self.image?.image = UIImage(data: $1)
            })
        }
    }

    func delete() {
        guard let url = self.url else {return}
        if let location = AssetManager.shared.get(cacheOf: url) {
            dismiss(animated: true) {
                let success = AssetManager.shared.remove(location.path)
                AlertManager.show(title: success ? "文件删除成功" : "文件删除失败", message: location.path, sender: self)
            }
        }
    }

    func share() {
        guard let url = self.url, let presentController = self.presentController else {return}
        if let location = AssetManager.shared.get(cacheOf: url) {
            let controller = UIActivityViewController(activityItems: [location], applicationActivities: nil)
            presentController.present(controller, animated: true, completion: nil)
        }
    }

    func saveToAlbum() {
        guard let url = self.url else {return}
        if let location = AssetManager.shared.get(cacheOf: url) {
            if let data = try? Data(contentsOf: location), let image = UIImage(data: data) {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
    }

    @objc func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo context: Any?) {
        AlertManager.show(title: error == nil ? "图片保存成功" : "图片保存失败", message: error?.debugDescription, sender: self)
    }
}

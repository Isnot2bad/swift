//
//  BarcodeImageViewController.swift
//  QRCode
//
//  Created by larryhou on 22/12/2015.
//  Copyright © 2015 larryhou. All rights reserved.
//

import Foundation
import UIKit

class BarcodeImageViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var inputTextView: UITextField!
    @IBOutlet weak var barcodeImageView: BarcodeImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

//        barcodeImageView.layer.borderWidth = 1.0
//        barcodeImageView.layer.borderColor = UIColor(white: 0.9, alpha: 1.0).CGColor

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func inputTextDidChange(_ sender: UITextField) {
        barcodeImageView.inputMessage = sender.text!
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

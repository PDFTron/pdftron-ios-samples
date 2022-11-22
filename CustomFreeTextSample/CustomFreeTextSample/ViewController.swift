//
//  ViewController.swift
//  CustomFreeTextSample
//
//  Created by Sahil Behl on 2022-11-21.
//

import UIKit
import PDFNet
import Tools

class ViewController: UIViewController {

    @IBOutlet weak var pdfView: PTPDFViewCtrl!
    @IBOutlet weak var addFreeTextAnnotation: UIButton!
    private var toolManager: PTToolManager? = nil

    
    override func viewDidLoad() {
        super.viewDidLoad()
        addFreeTextAnnotation.setTitle("Add annotation", for: UIControl.State.normal)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let pdfPath = Bundle.main.path(forResource: "sample", ofType: "pdf")
        
        guard let docToOpen = PTPDFDoc(filepath: pdfPath) else { return }

        pdfView.setDoc(docToOpen)
        self.toolManager = PTToolManager(pdfViewCtrl: self.pdfView)
        self.toolManager?.delegate = self
        pdfView.toolDelegate = toolManager
        self.toolManager?.changeTool(PTPanTool.self)
    }
    
    @IBAction func buttonTapped(_ sender: UIButton) {
        if let doc = pdfView.getDoc() {
            let page = doc.getPage(UInt32(pdfView.currentPage))
            
            
            let pageRect = page!.getCropBox()!
            let pageScreenRect = pdfView.pdfRectPage2CGRectScreen(pageRect, pageNumber: pdfView.currentPage)
            let centerX = CGRectGetMidX(pageScreenRect)
            let centerY = CGRectGetMidY(pageScreenRect)
            
            let width: CGFloat = 200
            let height: CGFloat = 250
            
            let rect = CGRect(x: centerX - width / 2, y: centerY - height / 2 , width: width, height: height)
            
            
            var txtannot: PTFreeText = PTFreeText.create(doc.getSDFDoc(), pos: pdfView.cgRectScreen2PDFRectPage(rect, pageNumber: pdfView.currentPage))
            txtannot.setContentRect(pdfView.cgRectScreen2PDFRectPage(rect, pageNumber: pdfView.currentPage))
            txtannot.setContents("Custom Text")
            
            page?.annotPushBack(txtannot)
            pdfView.update(with: txtannot, page_num: Int32(pdfView.currentPage))

            createAppearanceForFreeText(freeText: txtannot, onDoc: doc)
        }
    }
    
    private func createAppearanceForFreeText(freeText: PTAnnot, onDoc doc:PTPDFDoc) {
        doc.lock()
        guard let freeTextRect = freeText.getRect() else {
            doc.unlock()
            return
        }
        
        // create custom free text view from existing free text annotation
        
        let borderStyle = freeText.getBorderStyle()
        let borderWidth = borderStyle?.getWidth() ?? 0
        
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: freeTextRect.width(), height: freeTextRect.height()))
        let fillColor = PTColorDefaults.uiColor(from: freeText.getColorAsRGB(), compNum: 3)
        
        // set opacity on the background free text
        
        containerView.backgroundColor = fillColor?.withAlphaComponent(0.2)
        containerView.layer.borderColor = UIColor.red.cgColor
        containerView.layer.borderWidth = borderWidth
        
        let label = PTVectorLabel(frame: CGRect(x: 0, y: 0, width: freeTextRect.width() - borderWidth * 2, height: freeTextRect.height() - borderWidth * 2))
        label.numberOfLines =  0
        label.allowsDefaultTighteningForTruncation = false
        label.font = UIFont(name: "Helvetica", size: 12)
        label.textAlignment = .left
        label.textColor = .red
        label.contentMode = .top
        label.text = freeText.getContents()
        
        
        // create separated PDFs from both views
        let stampText = PTToolsUtil.createPTPDFDocFrom(from: label)
        let fullAppearanceDoc = PTToolsUtil.createPTPDFDocFrom(from: containerView)
        
        // combine into a single PDF
        
        if let pageOne = stampText.getPage(1) {
            let stamper = PTStamper(size_type: e_ptabsolute_size, a: pageOne.getWidth(e_ptmedia), b: pageOne.getHeight(e_ptmedia))

            stamper?.setAsAnnotation(false)
            stamper?.setAlignment(e_pthorizontal_left, vertical_alignment: e_ptvertical_top)
            stamper?.setPosition(borderWidth, vertical_distance: borderWidth, use_percentage: false)

            let pageSet = PTPageSet(one_page: 1)
            stamper?.stampPage(fullAppearanceDoc, src_page: pageOne, dest_pages: pageSet)

            let blankDoc = PTPDFDoc()
            if let blankPage = blankDoc?.pageCreate(fullAppearanceDoc.getPage(1).getVisibleContentBox()) {
                blankDoc?.pagePushBack(blankPage)

                let newStamper = PTStamper(size_type: e_ptabsolute_size, a: blankPage.getWidth(e_ptmedia), b: blankPage.getHeight(e_ptmedia))
                newStamper?.setAsAnnotation(true)
                newStamper?.setAlignment(e_pthorizontal_left, vertical_alignment: e_ptvertical_top)

                newStamper?.stampPage(blankDoc, src_page: fullAppearanceDoc.getPage(1), dest_pages: pageSet)

                let annot = blankDoc?.getPage(1).getAnnot(0)
                let app = annot?.getAppearance(e_ptnormal, app_state: nil)
                let destAnnotObj = doc.getSDFDoc().import(app, deep_copy: true)

                // set new appearance on free text
                freeText.setAppearance(destAnnotObj, annot_state: e_ptnormal, app_state: nil)
                doc.unlock()
                return
            }
        }
        doc.unlock()
        return
    }

}

extension ViewController: PTToolManagerDelegate {
    func viewController(for toolManager: PTToolManager) -> UIViewController {
        self
    }
    
    func toolManager(_ toolManager: PTToolManager, annotationModified annotation: PTAnnot, onPageNumber pageNumber: UInt) {
        if annotation.extendedAnnotType == .freeText {
            createAppearanceForFreeText(freeText: annotation, onDoc: pdfView.getDoc()!)
        }
    }
}


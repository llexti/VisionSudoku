//
//  VisionDetailsCollectionViewController.swift
//  VisionSudoku
//
//  Created by Laurent Lefevre on 05/11/2021.
//

import UIKit

class VisionDetailsCollectionViewController: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    var grid :[Int:GridElement]?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.collectionView.reloadData()
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

//================================================
//
//
// UICollectionView
//
//
//================================================
extension VisionDetailsCollectionViewController:UICollectionViewDelegate,UICollectionViewDelegateFlowLayout,UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "headerCourse", for: indexPath as IndexPath)
        return header
    }
    
    
    
    // MARK: UICollectionViewDataSource
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return (1)
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 128, height: 128)
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let grid = self.grid else {return 0}
        return (grid.count)
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellidentifier", for: indexPath)
        
        // Configure the cell
        let labelNom : UILabel? = cell.contentView.viewWithTag(100) as? UILabel
        let labelDigit : UILabel? = cell.contentView.viewWithTag(101) as? UILabel
        let imagePhoto : UIImageView? = cell.contentView.viewWithTag(200) as? UIImageView
        let gridCell = self.grid![indexPath.row]!
        if let image = gridCell.image {
            imagePhoto?.image=image
        } else {
            imagePhoto?.image=nil
        }
        labelNom?.text = "Cell #\(indexPath.row) \(Int(gridCell.accuracy*100/3))%"
        labelDigit?.text = (gridCell.value.count > 1) ? "" : "\(gridCell.value)"

        return cell
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
/*        if let cell = collectionView.cellForItem(at: indexPath) {
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        }
 */
    }

} // End of extension presenceViewController {

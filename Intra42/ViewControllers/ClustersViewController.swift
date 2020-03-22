//
//  ClustersViewController.swift
//  Intra42
//
//  Created by Felix Maury on 19/02/2020.
//  Copyright © 2020 Felix Maury. All rights reserved.
//

import UIKit

class ClustersViewController: UIViewController, ClustersViewDelegate {

    private let availableCampusIDs = [1, 5, 7, 8, 9, 12, 16, 17, 21]
    let noClusterLabel = UILabel()
    let noClusterView = UIView()
    var activityIndicator = UIActivityIndicatorView(style: .gray)
    
    var clustersData: [ClusterData] = []
    var clustersView: ClustersView?
    var clusters: [String: ClusterPerson] = [:]
    var selectedCampus: (id: Int, name: String) = (0, "") //Campus
    var selectedCell: UserProfileCell?
    var minZoomScale: CGFloat = 0.5
    
    @IBOutlet weak var headerSegment: UISegmentedControl!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var stackViewBottom: NSLayoutConstraint!
    
    @IBOutlet weak var infoView: UIView!
    @IBOutlet weak var infoViewHeight: NSLayoutConstraint!
    @IBOutlet weak var infoScrollview: UIScrollView!
    @IBOutlet weak var infoDragIndicator: UIView!
    @IBOutlet weak var infoStackview: UIStackView!
    private let minInfoContentHeight: CGFloat = 29
    private var infoContentHeight: CGFloat {
        CGFloat(clustersData.count * 55) + minInfoContentHeight
    }
    private var maxInfoContentHeight: CGFloat = 0
    private var originalContentHeight: CGFloat = 0
    
    // Array corresponding to infoStackView subviews containing user and friend count of cluster
    var occupancy: [(users: Int, friends: Int)] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Cluster Maps"
        noClusterView.backgroundColor = .white
        headerSegment.tintColor = API42Manager.shared.preferedPrimaryColor
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.backgroundColor = .systemBackground
            navigationItem.standardAppearance = appearance
            navigationItem.scrollEdgeAppearance = appearance
            
            activityIndicator.style = .medium
            noClusterView.backgroundColor = .systemBackground
            headerSegment.selectedSegmentTintColor = API42Manager.shared.preferedPrimaryColor
        }
        
        infoView.roundCorners(corners: [.topLeft, .topRight], radius: 20.0)
        infoDragIndicator.roundCorners(corners: .allCorners, radius: 2.0)
        
        activityIndicator.startAnimating()
        stackView.insertArrangedSubview(activityIndicator, at: 0)
        
        noClusterView.frame = view.frame
        noClusterLabel.frame = CGRect(x: 0, y: 0, width: view.frame.width - 40, height: 200)
        noClusterLabel.text = """
        
        Sorry, this campus' map is not available yet...
        
        Feel free to open an issue on github or contact me to help speed up the process!
        """
        noClusterLabel.textAlignment = .center
        noClusterLabel.numberOfLines = 0
        noClusterView.addSubview(noClusterLabel)
        noClusterLabel.center = noClusterView.convert(noClusterView.center, from: noClusterLabel)
        view.addSubview(noClusterView)
        
        if let id = API42Manager.shared.userProfile?.mainCampusId, let name = API42Manager.shared.userProfile?.mainCampusName {
            selectedCampus = (id, name)
            navigationItem.title = name
            if availableCampusIDs.contains(selectedCampus.id) {
                noClusterView.isHidden = true
                addNewClusterView()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if #available(iOS 13.0, *) {
            headerSegment.selectedSegmentTintColor = API42Manager.shared.preferedPrimaryColor
        } else {
            headerSegment.tintColor = API42Manager.shared.preferedPrimaryColor
        }
        for case let infoView as ClusterInfoView in infoStackview.arrangedSubviews {
            infoView.outerProgressBar.layer.borderColor = API42Manager.shared.preferedPrimaryColor?.cgColor
            infoView.innerProgressBar.backgroundColor = API42Manager.shared.preferedPrimaryColor
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        navigationController?.view.setNeedsLayout() // force update layout
        navigationController?.view.layoutIfNeeded() // to fix height of the navigation bar
    }
    
    func addNewClusterView(firstCampusLoad load: Bool = true) {
        let id = selectedCampus.id
        if !load || getClustersData(forCampus: id) {
            var pos = headerSegment.selectedSegmentIndex
            if pos < 0 { pos = 0 }
            
            let data = clustersData[pos]
            let height = (data.map.first?.count ?? 0) * 60
            let width = data.map.count * 40
    
            clustersView?.removeFromSuperview()
            
            let clustersView = ClustersView(withData: clustersData, forPos: pos, width: width, height: height)
            self.clustersView = clustersView
            clustersView.delegate = self
            
            minZoomScale = (UIScreen.main.bounds.width / CGFloat(max(width, height))) * 0.95
            
            scrollView.contentSize = clustersView.frame.size
            scrollView.addSubview(clustersView)
            scrollView.minimumZoomScale = minZoomScale
            scrollView.maximumZoomScale = 4.0
            scrollView.zoomScale = minZoomScale
            
            let clusterHeight = CGFloat(max(width, height)) * minZoomScale
            maxInfoContentHeight = view.bounds.height - (clusterHeight + 60)
            if infoViewHeight.constant != minInfoContentHeight {
                showInfoView()
            }

            if load {
                loadClusterLocations(forCampus: id)
            } else {
                self.clustersView?.locations = self.clusters
                self.clustersView?.setupLocations()
                activityIndicator.removeFromSuperview()
            }
        }
    }
    
    func getClustersData(forCampus id: Int) -> Bool {
        if availableCampusIDs.contains(id) {
            let name = "cluster_map_campus_\(id)"
            print("Getting map: \(name)")
            if let path = Bundle.main.path(forResource: name, ofType: "json") {
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                    clustersData = try JSONDecoder().decode([ClusterData].self, from: data)

                    headerSegment.isHidden = clustersData.count < 2
                    headerSegment.removeAllSegments()
                    occupancy = []
                    for (index, cluster) in clustersData.enumerated() {
                        headerSegment.insertSegment(withTitle: cluster.nameShort, at: index, animated: false)
                        occupancy.append((0, 0))
                    }
                    headerSegment.selectedSegmentIndex = 0
                    return true
                } catch let DecodingError.dataCorrupted(context) {
                    print(context)
                } catch let DecodingError.keyNotFound(key, context) {
                    print("Key '\(key)' not found:", context.debugDescription)
                    print("codingPath:", context.codingPath)
                } catch let DecodingError.valueNotFound(value, context) {
                    print("Value '\(value)' not found:", context.debugDescription)
                    print("codingPath:", context.codingPath)
                } catch let DecodingError.typeMismatch(type, context) {
                    print("Type '\(type)' mismatch:", context.debugDescription)
                    print("codingPath:", context.codingPath)
                } catch {
                    print("error: ", error)
                }
            }
        }
        noClusterView.isHidden = false
        return false
    }
    
    func loadClusterLocations(forCampus id: Int) {
        API42Manager.shared.getLocations(forCampusId: id, page: 1) { (data) in
            var clusters: [String: ClusterPerson] = [:]
            self.occupancy = Array(repeating: (0, 0), count: self.occupancy.count)
            
            print("LOCATION DATA")
            print(data)
            for location in data {
                let host = location["host"].stringValue
                let name = location["user"]["login"].stringValue
                let id = location["user"]["id"].intValue
                
                for (index, cluster) in self.clustersData.enumerated() {
                    if host.contains(cluster.hostPrefix) {
                        self.occupancy[index].users += 1
                        if FriendDataManager.shared.hasFriend(withId: id) {
                            self.occupancy[index].friends += 1
                        }
                    }
                }
                clusters.updateValue(ClusterPerson(id: id, name: name), forKey: host)
            }
            self.clusters = clusters
            self.clustersView?.locations = clusters
            self.clustersView?.setupLocations()
            self.setupClusterInfo()
            self.navigationItem.rightBarButtonItems![0].isEnabled = true
            self.activityIndicator.removeFromSuperview()
        }
    }
    
    func setupClusterInfo() {
        for case let infoView as ClusterInfoView in infoStackview.arrangedSubviews {
            infoView.removeFromSuperview()
        }
        if clustersData.isEmpty {
            infoView.isHidden = true
            return
        }
        for case let (index, cluster) in clustersData.enumerated() {
            let infoView = ClusterInfoView()
            let friends = occupancy[index].friends
            let friendText = "\(friends) friend\(friends == 1 ? "" : "s")"
            let users = occupancy[index].users
            let total = cluster.capacity
            let progText = "\(users)/\(total)"
            infoView.friendsLabel.text = friendText
            infoView.nameLabel.text = cluster.name
            infoView.progressLabel.text = progText
            let progress = (Double(users) / Double(total) * Double(infoView.frame.width - 40))
            setClusterOccupancy(
                backBar: infoView.outerProgressBar,
                progressBar: infoView.innerProgressBar,
                progress: progress
            )
            infoStackview.addArrangedSubview(infoView)
        }
    }
    
    func setClusterOccupancy(backBar: UIView, progressBar: UIView, progress: Double) {
        progressBar.frame = CGRect(x: 0, y: 0, width: progress, height: Double(backBar.frame.height))
        progressBar.roundCorners(corners: [.topLeft, .bottomLeft], radius: 5.0)
        progressBar.backgroundColor = API42Manager.shared.preferedPrimaryColor
        backBar.layer.cornerRadius = 5.0
        backBar.layer.borderWidth = 1.0
        backBar.layer.borderColor = API42Manager.shared.preferedPrimaryColor?.cgColor
        backBar.clipsToBounds = true
    }
    
    @IBAction func panInfoView(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self.view).y
        let velocity = gesture.velocity(in: self.view).y
        
        switch gesture.state {
        case .began:
            originalContentHeight = infoViewHeight.constant
            scrollView.isScrollEnabled = false
        case .changed:
            let newHeight = originalContentHeight - translation
            
            if newHeight < view.bounds.height - 100 && newHeight > minInfoContentHeight {
                if newHeight > infoContentHeight {
                    let extra = newHeight - infoContentHeight
                    infoViewHeight.constant = infoContentHeight + (extra / log(extra))
                } else {
                    infoViewHeight.constant = newHeight
                }
            }
        case .ended, .cancelled:
            if infoViewHeight.constant > view.bounds.height - 150 || velocity < -3000.0 {
                let newHeight = min(view.bounds.height - 100, infoContentHeight)
                let timeNeeded = Double(abs(newHeight - infoViewHeight.constant) / velocity)
                infoViewHeight.constant = newHeight
                UIView.animate(withDuration: timeNeeded) {
                    self.infoView.superview?.layoutIfNeeded()
                }
            } else if infoViewHeight.constant > 100 && velocity < 3000.0 {
                showInfoView()
            } else {
                let timeNeeded = Double(infoViewHeight.constant / velocity)
                hideInfoView(withDuration: timeNeeded)
            }
        default:
            break
        }
    }

    @IBAction func clusterFloorChanged(_ sender: UISegmentedControl) {
        stackView.insertArrangedSubview(activityIndicator, at: 0)
        scrollView.setZoomScale(minZoomScale, animated: true)
        clustersView?.clearUserImages()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.addNewClusterView(firstCampusLoad: false)
            for case let infoView as ClusterInfoView in self.infoStackview.arrangedSubviews {
                infoView.isHidden = false
            }
        }
    }
    
    func refreshClusters() {
        hideInfoView()
        stackView.insertArrangedSubview(activityIndicator, at: 0)
        navigationItem.rightBarButtonItems![0].isEnabled = false
        clustersView?.clearUserImages()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadClusterLocations(forCampus: self.selectedCampus.id)
            self.scrollView.setZoomScale(self.minZoomScale, animated: true)
        }
    }
    
    @IBAction func showOptions(_ sender: Any) {
        let optionsAction = UIAlertController(title: "Options", message: nil, preferredStyle: .actionSheet)
        let changeCampus = UIAlertAction(title: "Change campus", style: .default) { [weak self] (_) in
            guard let self = self else { return }
            let campusController = TablePickerController()
            campusController.modalPresentationStyle = .fullScreen
            campusController.delegate = self
            campusController.selectedItem = self.selectedCampus
            campusController.dataSource = { refresh, completionHandler in
                API42Manager.shared.getAllCampus(refresh: refresh) { campuses in
                    completionHandler(campuses.filter { self.availableCampusIDs.contains($0.id) })
                }
            }
            _ = campusController.view
            self.navigationController?.pushViewController(campusController, animated: true)
        }
        let refresh = UIAlertAction(title: "Refresh", style: .destructive) { [weak self] (_) in
            self?.refreshClusters()
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        optionsAction.addAction(changeCampus)
        optionsAction.addAction(refresh)
        optionsAction.addAction(cancel)
        present(optionsAction, animated: true, completion: nil)
    }
    
    @IBAction func tapInfoView(_ sender: UITapGestureRecognizer) {
        if infoViewHeight.constant == minInfoContentHeight {
            showInfoView()
        }
    }
    
    private func showInfoView(withDuration duration: Double = 0.5) {
        print("SHOWING INFO")
        print("\(duration)s")
        print("MAX Height: \(maxInfoContentHeight)")
        print("MIN Height: \(minInfoContentHeight)")
        print("Height: \(infoContentHeight)")
        if infoContentHeight <= minInfoContentHeight {
            infoViewHeight.constant = minInfoContentHeight
        } else if infoContentHeight > maxInfoContentHeight {
            infoViewHeight.constant = maxInfoContentHeight - 20
        } else {
            infoViewHeight.constant = infoContentHeight
        }
        stackViewBottom.constant = infoViewHeight.constant
        UIView.animate(withDuration: duration) {
            self.infoView.superview?.layoutIfNeeded()
        }
    }
    
    private func hideInfoView(withDuration duration: Double = 0.5) {
        self.stackViewBottom.constant = minInfoContentHeight
        self.infoViewHeight.constant = minInfoContentHeight
        UIView.animate(withDuration: duration) {
            self.infoView.superview?.layoutIfNeeded()
        }
    }
}

// MARK: - Prepare for segue

extension ClustersViewController: UserProfileDataSource {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "UserProfileSegue" {
            if let destination = segue.destination as? UserProfileController {
                showUserProfileController(atDestination: destination)
            }
        }
    }
}

// MARK: - Table Picker Delegate

extension ClustersViewController: TablePickerDelegate {
    
    func selectItem(_ item: TablePickerItem) {
        selectedCampus = item
        navigationItem.title = item.name
        if availableCampusIDs.contains(item.id) {
            stackView.insertArrangedSubview(activityIndicator, at: 0)
            noClusterView.isHidden = true
            for case let infoView as ClusterInfoView in infoStackview.arrangedSubviews {
                infoView.removeFromSuperview()
            }
            addNewClusterView()
        } else {
            noClusterView.isHidden = false
        }
    }
}

// MARK: - Scroll View Delegate

extension ClustersViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return clustersView
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        hideInfoView()
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scale == minZoomScale {
            showInfoView()
        }
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(top: 0, left: offsetX, bottom: 0, right: 0)
    }
}

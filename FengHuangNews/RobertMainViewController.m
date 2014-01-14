//
//  RobertMainViewController.m
//  FengHuangNews
//
//  Created by Ceasarback on 14-1-2.
//  Copyright (c) 2014年 _CompanyName_. All rights reserved.
//

#import "RobertMainViewController.h"
#import "RobertMyCell.h"
#import "DPHTTPRequest.h"
#import "ContentModel.h"
#import "UIImageView+WebImage.h"
#import "WebImageManager.h"

#define kNewsURL @"http://api.3g.ifeng.com/iosNews?id=aid=SYLB10,SYDT10,SYRECOMMEND&imgwidth=100&type=list&pagesize=20&gv=4.2.0&av=0&uid=C395A6D5F8854A3CBCFA611D59013C76&proid=ifengnews&os=ios_7.0.4&df=iPhone6,2&vt=5&screen=640x1136&publishid=2002"

@interface RobertMainViewController ()

@property (nonatomic, retain)   UIScrollView    *scrollView;
@property (nonatomic, retain)   UITableView     *tableView;
@property (nonatomic, retain)   NSMutableArray  *contentsData;
@property (nonatomic, retain)   NSMutableArray  *headerData;
@property (nonatomic, retain)   UIActivityIndicatorView *aiv;
@property (nonatomic, retain)   UIView          *aivBGView;

@end

@implementation RobertMainViewController

- (void)dealloc
{
    self.scrollView = nil;
    self.tableView = nil;
    self.contentsData = nil;
    self.headerData = nil;
    self.aiv = nil;
    self.aivBGView = nil;
    
    [super dealloc];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}


#pragma mark - HttpRequestDelegate


- (void)downloadFinished:(DPHTTPRequest *)request
{
    [_aiv stopAnimating];
    _aivBGView.hidden = YES;
    
    //
    NSError *error = nil;
    NSArray *array = [NSJSONSerialization JSONObjectWithData:request.responseData options:NSJSONReadingMutableContainers error:&error];
    if (error)
    {
        return;
    }
    
    for (NSDictionary *item in [[[array firstObject]objectForKey:@"body"] objectForKey:@"item"])
    {
        ContentModel *model = [[ContentModel alloc] initWithData:item];
        [_contentsData addObject:model];
        [model release];
    }
    
    [_tableView reloadData];
    [self loadCurrentScreenImage];
    
    
    // scrollView
    for (NSDictionary *item in [[[array objectAtIndex:1]objectForKey:@"body"] objectForKey:@"item"])
    {
        ContentModel *model = [[ContentModel alloc] initWithData:item];
        [_headerData addObject:model];
        [model release];
    }
    [self loadHeader]; 
}

- (void)downloadFailed:(DPHTTPRequest *)request
{
    NSLog(@"%@", request.responseError);
}


#pragma mark - Lifecryle


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
    _scrollView.pagingEnabled = YES;
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.tableHeaderView = _scrollView;
    _tableView.contentInset = UIEdgeInsetsMake(20, 0, 0, 0);
    [self.view addSubview:_tableView];
    
    _headerData = [[NSMutableArray alloc] initWithCapacity:0];
    _contentsData = [[NSMutableArray alloc] initWithCapacity:0];
    
    _aiv = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    _aiv.center = CGPointMake(100, 100);
    _aiv.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    _aivBGView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
    _aivBGView.center = CGPointMake(self.view.frame.size.width/2.0f, self.view.frame.size.height/2.0f);
    _aivBGView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.7];
    [_aivBGView addSubview:_aiv];
    _aivBGView.hidden = YES;
    _aivBGView.layer.cornerRadius = 10.0f;
    [self.view addSubview:_aivBGView];
    
    DPHTTPRequest *request = [DPHTTPRequest requestWithURLString:kNewsURL andDelegate:self];
    [request setDidFinishedSeletor:@selector(downloadFinished:)];
    [request setDidFailedSeletor:@selector(downloadFailed:)];
    [request sendWithAsync];
    _aivBGView.hidden = NO;
    [_aiv startAnimating];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - UITableViewDataSource


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_contentsData count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 100;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    RobertMyCell *cell = (RobertMyCell *)[tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell == nil)
    {
        cell = [[[NSBundle mainBundle] loadNibNamed:@"RobertMyCell" owner:self options:nil] lastObject];
    }
    
    ContentModel *m = [_contentsData objectAtIndex:indexPath.row];
    cell.summary.text = m.title;
    cell.comment.text = [NSString stringWithFormat:@"%@评论", m.commentsAll];
    
    UIImage *image = [[WebImageManager shareManager] getCacheImage:m.thumbnail];
    if (image)
        cell.iconView.image = image;

    return cell;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate)
    {
        [self loadCurrentScreenImage];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self loadCurrentScreenImage];
}


#pragma mark - HelperMother

- (void)loadCurrentScreenImage
{
    NSArray *cells = [_tableView visibleCells];
    for (RobertMyCell *cell in cells)
    {
        NSIndexPath *indexPath = [_tableView indexPathForCell:cell];
        ContentModel *m = [_contentsData objectAtIndex:indexPath.row];
        [cell.iconView setImageWithURLString:m.thumbnail];
    }
}

- (void)loadHeader
{
    int i = 0;
    for (ContentModel *m in _headerData)
    {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(i*320, 0, 320, 200)];
        [imageView setImageWithURLString:m.thumbnail];
        [_scrollView addSubview:imageView];
        [imageView release];
        i++;
    }
    
    _scrollView.contentSize = CGSizeMake(i*320, 200);
}

@end

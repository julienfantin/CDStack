# CDStack
> Simplified CoreData stack management


## Rationale
CDStacks aims to make it easy to use a simple CoreData configuration, and easier to manage complex setups with possibly asynchronous data stores.

What's commonly described as a CoreData stack usually refers to an instance of `NSPersistentStoreCoordinator`, its configuration and related objects.

```objective-c
	@interface MyAppDelegate
	@property (strong, nonatomic) CDStack *stack;
	@end
	@implementation CDAppDelegate
	@synthesize stack = _stack;
	- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
	{
		self.stack = [[CDStack alloc] initWithStoreClass:[CDSQLiteStore class]];
	    // init app
		return YES;
	}
  ```

The details of this particular stack are defined on `CDSQLiteStore` which adopts the `CDPersistentStore` prorocol.

```objective-c
	@protocol CDPersistentStore <NSObject>
	@required
	+ (NSString *)type;
	@optional
	+ (NSURL *)url;
	+ (NSString *)configuration;
	+ (NSDictionary *)options;
	@end
 ```

This makes for a designated place to store your stack's configuration.

- Threading
  - Block-based fetching API for non-blocking operations
  - Background fetches and saves using Grand Central Dispatch
  - Automatically handle `NSManagedObjectContext` thread confinment
- UI-friendly fetching with GCD


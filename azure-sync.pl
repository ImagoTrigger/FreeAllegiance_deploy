use Net::Azure::StorageClient::Blob;

my $blobService = Net::Azure::StorageClient::Blob->new(
                                    account_name => 'azcdn',
                                    primary_access_key => 'q2IfR7j2hlHjnGLkcQlL0IlY0dKfiDW9ut+PRmAaFnOGnLX6jXcQpBT66RsmgwWX3rO9fx6BDeny0on8iUC96Q==',
                                    protocol => 'http',
				);

my $params = { threads => 2, direction => 'upload', include_invisible => 1, subdir => 'Game'};
my $res = $blobService->sync( 'autoupdate', 'C:\\build\\Autoupdate\\Game', $params );
function Get-GHRepoLatestTag {
    param(
        [Parameter(Mandatory)]
        [string]$Org,
        [Parameter(Mandatory)]
        [string]$Repo
    )
    $Query = @"
query {
  repository(owner: "$Org", name: "$Repo") {
    refs(refPrefix: "refs/tags/", first: 1, orderBy: {field: TAG_COMMIT_DATE, direction: DESC}) {
      nodes {
        name
        target {
          ... on Commit {
            committedDate
            message
          }
        }
      }
    }
  }
}
"@

    $irmSplat = @{
        Headers = @{
            Authorization = "bearer $env:GITHUB_TOKEN"
            Accept        = 'application/vnd.github.v4.json'
        }
        Uri     = 'https://api.github.com/graphql'
        Body    = @{ query = $query } | ConvertTo-Json -Compress
        Method  = 'POST'
    }
    $result = Invoke-RestMethod @irmSplat
    $result.data.repository.refs.nodes
}
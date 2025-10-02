export interface PersonalMetrics {
  pull_requests_created: number
  pull_requests_merged: number
  commits: number
  issues_closed: number
  pr_comments: number
  review_comments: number
  repositories: string[]
}

export interface RepositoryMetrics {
  name: string
  pull_requests: number
  merged_prs: number
  commits: number
  closed_issues: number
  contributors: string[]
  contributor_count: number
}

export interface Summary {
  total_repositories: number
  total_pull_requests: number
  merged_pull_requests: number
  total_commits: number
  closed_issues: number
  unique_contributors: number
}

export interface GitHubMetrics {
  period: string
  collected_at: string
  organization: string
  repository?: string
  summary: Summary
  repositories: RepositoryMetrics[]
  personal_metrics: Record<string, PersonalMetrics>
}

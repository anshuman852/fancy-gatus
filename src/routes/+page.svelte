<script lang="ts">
  import axios from 'axios'
  import type { AxiosError } from 'axios'
  import { onMount } from 'svelte'
  import type { Config } from '$lib/types/config'
  import type { Status } from '$lib/types/api'
  import Loader from '$lib/components/Loader.svelte'
  import Header from '$lib/components/Header.svelte'
  import Notice from '$lib/components/Notice.svelte'
  import OverallStatus from '$lib/components/OverallStatus.svelte'
  import EndpointGroup from '$lib/components/StatusGroup.svelte'
  import RefreshSettings from '$lib/components/RefreshSettings.svelte'
  import Footer from '$lib/components/Footer.svelte'

  let loading = $state(true)
  let config: Config = $state({})
  let apiData: Status[] = $state([])

  async function getConfig() {
    try {
      const response = await axios.get('config.json', { baseURL: '/' })

      config = response.data
      // Set title if defined in config
      if (config.title) {
        document.title = config.title
      }
    } catch (err) {
      const error = err as AxiosError
      if (error.response && error.response.status === 404) {
        console.warn('No config.json file found. Using default values.')
      }
      console.log('Error getting config: ' + error)
    }
  }

  async function getApiData() {
    // Set base URL for API calls if defined in config
    if (config.gatusBaseUrl && axios.defaults.baseURL !== config.gatusBaseUrl) {
      axios.defaults.baseURL = config.gatusBaseUrl
    }

    try {
      const response = await axios.get('/api/v1/endpoints/statuses')
      apiData = response.data
      loading = false
    } catch (error) {
      console.log(error)
    }
  }

  async function refresh() {
    await getConfig()
    await getApiData()
  }

  // Group statuses by their group name
  // and sort them according to the config if specified
  let groups: { title: string; statuses: Status[] }[] = $derived.by(() => {
    // Group statuses by group name
    let groups: Map<string, Status[]> = new Map<string, Status[]>()
    apiData.map((status) => {
      // Filter statuses that should be hidden
      if (config.hiddenStatuses?.includes(status.name)) return
      if (!status.group) {
        status.group = 'Ungrouped'
      }
      // Filter groups that should be hidden
      if (config.hiddenGroups?.includes(status.group)) return
      let groupStatuses = groups.get(status.group) || []
      groupStatuses.push(status)
      groups.set(status.group, groupStatuses)
    })

    // Sort by config
    let tmp = groups
    let sortedGroups: { title: string; statuses: Status[] }[] = []
    if (config.groupOrder) {
      config.groupOrder.forEach((key) => {
        if (tmp.has(key)) {
          sortedGroups.push({ title: key, statuses: tmp.get(key)! })
          tmp.delete(key)
        }
      })
    }

    // Sort remaining group alphabetically
    let sortedKeys = [...tmp.keys()].sort((a, b) => a.localeCompare(b))
    sortedKeys.map((key) => {
      let statuses = tmp.get(key)!
      sortedGroups.push({ title: key, statuses })
    })
    return sortedGroups
  })

  // Array of statuses where the last result has success = false
  let failedStatuses = $derived.by(() => {
    const filteredStatuses = groups.flatMap((item) => item.statuses)
    return filteredStatuses.filter((status) => {
      return !status.results[status.results.length - 1].success
    })
  })

  onMount(() => {
    refresh()
  })
</script>

{#if loading}
  <Loader />
{:else}
  <Header title={config.title} />
  {#if config.notice}
    <Notice notice={config.notice} />
  {/if}
  <OverallStatus {failedStatuses} />
  {#each groups as group (group.title)}
    <EndpointGroup
      title={group.title}
      statuses={group.statuses}
      expandByDefault={config.defaultExpandGroups}
      {config}
    />
  {/each}
  <RefreshSettings defaultRefreshInterval={config.defaultRefreshInterval} onRefresh={refresh} />
  <Footer />
{/if}

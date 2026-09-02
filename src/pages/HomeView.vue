<script setup lang="ts">
/**
 * HomeView — Registration MVP（P0）首頁。
 *
 * 完整品牌設定（Logo、Hero、公告、FAQ，MASTER_SPEC.md 第 32-33 節）留待 P1
 * 之後的 Admin Foundation 完整實作，這裡先提供最基本的導引：進去瀏覽目前
 * 開放報名的期課。
 */
</script>

<template>
  <section class="mx-auto max-w-2xl">
    <h1 class="text-2xl font-bold text-gray-900">舞蹈課程管理系統</h1>
    <p class="mt-2 text-gray-600">歡迎！請瀏覽目前開放報名的期課，登入或註冊後即可線上報名。</p>
    <RouterLink to="/courses" class="mt-4 inline-block rounded bg-gray-900 px-4 py-2 text-white">
      瀏覽開放報名的課程
    </RouterLink>
  </section>
</template>

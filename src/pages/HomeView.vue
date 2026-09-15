<script setup lang="ts">
import { useAuth } from '@/composables/useAuth'

const { isLoggedIn, isAdmin } = useAuth()
</script>
<template>
  <div class="mx-auto max-w-6xl space-y-14 pb-8">
    <section
      class="relative overflow-hidden rounded-[2rem] border border-pink-100 bg-gradient-to-br from-white via-pink-50 to-sky-50 shadow-sm"
    >
      <div class="grid items-stretch lg:grid-cols-[1.05fr_0.95fr]">
        <div
          class="relative z-10 order-2 flex flex-col justify-center px-6 py-10 sm:px-10 sm:py-14 lg:order-1 lg:px-14 lg:py-20"
        >
          <p
            class="mb-5 inline-flex w-fit rounded-full bg-pink-100 px-4 py-2 text-xs font-bold tracking-[0.2em] text-pink-700"
          >
            ANGEL ZUMBA CLASS
          </p>

          <h1 class="text-4xl font-black leading-tight text-gray-950 sm:text-5xl lg:text-6xl">
            Move with joy.
            <span class="mt-2 block text-pink-600">Shine your energy.</span>
          </h1>

          <p class="mt-6 max-w-xl text-base leading-7 text-gray-600 sm:text-lg">
            和 Angel 一起跳舞、流汗、開心釋放能量。 從第一次接觸 Zumba
            到愛上每一個節奏，這裡都歡迎你。
          </p>

          <p class="mt-4 text-sm font-semibold tracking-[0.16em] text-gray-500">
            SHINE. MOVE. SMILE.
          </p>

          <div class="mt-8 flex flex-wrap gap-3">
            <RouterLink
              to="/courses"
              class="rounded-full bg-gray-950 px-6 py-3 text-sm font-bold text-white shadow-lg shadow-gray-300 transition hover:-translate-y-0.5 hover:bg-pink-600"
            >
              查看課程與報名
            </RouterLink>

            <RouterLink
              v-if="!isLoggedIn"
              to="/login"
              class="rounded-full border border-gray-300 bg-white px-6 py-3 text-sm font-bold text-gray-800 transition hover:border-pink-300 hover:text-pink-700"
            >
              學生登入
            </RouterLink>

            <RouterLink
              v-else-if="isAdmin"
              to="/admin/registrations"
              class="rounded-full border border-gray-300 bg-white px-6 py-3 text-sm font-bold text-gray-800 transition hover:border-pink-300 hover:text-pink-700"
            >
              管理後台
            </RouterLink>

            <RouterLink
              v-else
              to="/my-registrations"
              class="rounded-full border border-gray-300 bg-white px-6 py-3 text-sm font-bold text-gray-800 transition hover:border-pink-300 hover:text-pink-700"
            >
              我的報名
            </RouterLink>
          </div>

          <p v-if="!isLoggedIn" class="mt-5 text-xs leading-5 text-gray-500">
            第一次使用請先註冊；報名完成後，請於24小時內完成付款。
          </p>
        </div>

        <div
          class="relative order-1 min-h-[380px] overflow-hidden bg-gray-100 sm:min-h-[520px] lg:order-2"
        >
          <div
            class="pointer-events-none absolute inset-0 z-10 bg-gradient-to-t from-white/35 via-transparent to-transparent lg:bg-gradient-to-r lg:from-pink-50/80 lg:via-transparent lg:to-transparent"
          ></div>

          <picture>
            <source srcset="/images/angel-hero.webp" type="image/webp" />
            <img
              src="/images/angel-hero.jpg"
              alt="Angel Zumba 舞蹈動態照片"
              class="absolute inset-0 h-full w-full object-cover object-[50%_35%]"
              loading="eager"
              fetchpriority="high"
            />
          </picture>

          <div
            class="absolute bottom-5 right-5 z-20 hidden rounded-2xl border border-white/70 bg-white/80 px-4 py-3 shadow-lg backdrop-blur lg:block"
          >
            <p class="text-xs font-semibold tracking-wider text-gray-500">ZUMBA WITH</p>
            <p class="mt-1 text-xl font-black text-gray-900">ANGEL</p>
          </div>
        </div>
      </div>
    </section>

    <section>
      <div class="text-center">
        <p class="text-sm font-bold tracking-[0.18em] text-pink-600">START HERE</p>
        <h2 class="mt-3 text-2xl font-black text-gray-900 sm:text-3xl">第一次使用，很簡單</h2>
        <p class="mx-auto mt-3 max-w-2xl text-sm leading-6 text-gray-600 sm:text-base">
          註冊帳號、選擇課程，再到「我的報名」確認內容與付款資訊。
        </p>
      </div>

      <div class="mt-8 grid gap-4 md:grid-cols-3">
        <article class="rounded-3xl border border-gray-200 bg-white p-6 shadow-sm">
          <span
            class="flex h-10 w-10 items-center justify-center rounded-full bg-pink-100 text-sm font-black text-pink-700"
          >
            01
          </span>
          <template v-if="!isLoggedIn">
            <h3 class="mt-5 text-lg font-bold text-gray-900">註冊或登入</h3>
            <p class="mt-2 text-sm leading-6 text-gray-600">
              第一次使用請以中文本名、本人手機號碼及6位數PIN完成註冊。
            </p>
            <RouterLink to="/register" class="mt-4 inline-block text-sm font-bold text-pink-700">
              前往註冊 →
            </RouterLink>
          </template>

          <template v-else-if="isAdmin">
            <h3 class="mt-5 text-lg font-bold text-gray-900">管理員已登入</h3>
            <p class="mt-2 text-sm leading-6 text-gray-600">
              可直接前往管理後台查看報名、付款與課程資料。
            </p>
            <RouterLink
              to="/admin/registrations"
              class="mt-4 inline-block text-sm font-bold text-pink-700"
            >
              前往管理後台 →
            </RouterLink>
          </template>

          <template v-else>
            <h3 class="mt-5 text-lg font-bold text-gray-900">帳號已登入</h3>
            <p class="mt-2 text-sm leading-6 text-gray-600">
              你已完成登入，可以直接選擇課程或查看自己的報名紀錄。
            </p>
            <RouterLink
              to="/my-registrations"
              class="mt-4 inline-block text-sm font-bold text-pink-700"
            >
              查看我的報名 →
            </RouterLink>
          </template>
        </article>

        <article class="rounded-3xl border border-gray-200 bg-white p-6 shadow-sm">
          <span
            class="flex h-10 w-10 items-center justify-center rounded-full bg-sky-100 text-sm font-black text-sky-700"
          >
            02
          </span>
          <h3 class="mt-5 text-lg font-bold text-gray-900">選擇課程</h3>
          <p class="mt-2 text-sm leading-6 text-gray-600">
            查看實際上課日期、時間、場地、費用及剩餘名額，再送出報名。
          </p>
          <RouterLink to="/courses" class="mt-4 inline-block text-sm font-bold text-sky-700">
            瀏覽課程 →
          </RouterLink>
        </article>

        <article class="rounded-3xl border border-gray-200 bg-white p-6 shadow-sm">
          <span
            class="flex h-10 w-10 items-center justify-center rounded-full bg-amber-100 text-sm font-black text-amber-700"
          >
            03
          </span>
          <h3 class="mt-5 text-lg font-bold text-gray-900">確認並付款</h3>
          <p class="mt-2 text-sm leading-6 text-gray-600">
            報名後請至「我的報名」確認資料，並於24小時內完成付款。
          </p>
          <RouterLink
            to="/my-registrations"
            class="mt-4 inline-block text-sm font-bold text-amber-700"
          >
            查看我的報名 →
          </RouterLink>
        </article>
      </div>
    </section>

    <section
      class="overflow-hidden rounded-[2rem] bg-gray-950 px-6 py-9 text-white sm:px-10 sm:py-11"
    >
      <div class="flex flex-col justify-between gap-7 md:flex-row md:items-center">
        <div>
          <p class="text-sm font-bold tracking-[0.18em] text-pink-300">SEE YOU IN CLASS</p>
          <h2 class="mt-3 text-2xl font-black sm:text-3xl">準備好一起跳舞了嗎？</h2>
          <p class="mt-3 max-w-2xl text-sm leading-6 text-gray-300">
            名額有限，額滿後系統將無法受理。若課程暫停期課報名，仍可查看完整課程資訊。
          </p>
        </div>

        <RouterLink
          to="/courses"
          class="w-fit shrink-0 rounded-full bg-pink-500 px-6 py-3 text-sm font-bold text-white transition hover:bg-pink-400"
        >
          查看目前課程
        </RouterLink>
      </div>
    </section>
  </div>
</template>

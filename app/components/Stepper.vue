<template>
  <div class="w-full" v-bind="$attrs">
    <div
      :class="['w-full overflow-hidden', stepCircleContainerClassName]"
      :style="{
        border:
          borderColor !== 'transparent' ? `1px solid ${borderColor}` : 'none',
      }"
    >
      <div
        :class="['flex w-full items-center px-8 pt-8', stepContainerClassName]"
      >
        <template v-for="(_, index) in stepsArray" :key="index + 1">
          <component
            :is="renderStepIndicator"
            v-if="renderStepIndicator"
            :current-step="currentStep"
            :on-step-click="handleCustomStepClick"
            :step="index + 1"
          />

          <button
            v-else
            :disabled="disableStepIndicators || index + 1 > currentStep"
            :style="{
              pointerEvents:
                disableStepIndicators || index + 1 > currentStep
                  ? 'none'
                  : undefined,
              opacity:
                disableStepIndicators || index + 1 > currentStep ? 0.5 : 1,
            }"
            class="relative cursor-pointer outline-none"
            type="button"
            @click="handleStepIndicatorClick(index + 1)"
          >
            <Motion
              :animate="getStepStatus(index + 1)"
              :initial="false"
              :transition="{ duration: 0.3 }"
              :variants="indicatorVariants"
              as="div"
              class="flex h-8 w-8 items-center justify-center rounded-full font-semibold"
            >
              <svg
                v-if="getStepStatus(index + 1) === 'complete'"
                :style="{ color: checkColor }"
                class="h-4 w-4"
                fill="none"
                stroke="currentColor"
                stroke-width="2.5"
                viewBox="0 0 24 24"
              >
                <Motion
                  :animate="{ pathLength: 1 }"
                  :initial="{ pathLength: 0 }"
                  :transition="{
                    delay: 0.1,
                    type: 'tween',
                    ease: 'easeOut',
                    duration: 0.3,
                  }"
                  as="path"
                  d="M5 13l4 4L19 7"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>

              <span
                v-else-if="getStepStatus(index + 1) === 'active'"
                :style="{ backgroundColor: dotColor }"
                class="h-3 w-3 rounded-full"
              />

              <span v-else class="text-sm">
                {{ index + 1 }}
              </span>
            </Motion>
          </button>

          <div
            v-if="index < totalSteps - 1"
            :style="{ backgroundColor: lineBackgroundColor }"
            class="relative mx-2 h-0.5 flex-1 overflow-hidden rounded"
          >
            <Motion
              :animate="
                currentStep > index + 1 || completedSteps.includes(index + 1)
                  ? 'complete'
                  : 'incomplete'
              "
              :initial="false"
              :style="{
                backgroundColor: lineCompleteColor,
              }"
              :transition="{ duration: 0.4 }"
              :variants="lineVariants"
              as="div"
              class="absolute top-0 left-0 h-full"
            />
          </div>
        </template>
      </div>

      <Motion
        :animate="{
          height: isCompleted ? 0 : parentHeight,
        }"
        :class="contentClassName"
        :transition="{
          type: 'spring',
          duration: 0.4,
        }"
        as="div"
        style="position: relative; overflow: hidden"
      >
        <AnimatePresence :custom="direction" :initial="false" mode="sync">
          <Motion
            v-if="!isCompleted"
            :key="currentStep"
            v-layout-height="measureHeight"
            :custom="direction"
            :transition="{ duration: 0.4 }"
            :variants="stepVariants"
            animate="center"
            as="div"
            exit="exit"
            initial="enter"
            style="position: absolute; left: 0; right: 0; top: 0"
          >
            <div class="px-8">
              <component :is="stepsArray[currentStep - 1]" />
            </div>
          </Motion>
        </AnimatePresence>
      </Motion>

      <div
        v-if="!isCompleted && !isLastStep"
        :class="['px-8 pb-8', footerClassName]"
      >
        <div
          :class="[
            'mt-8 flex',
            currentStep > 1 ? 'justify-between' : 'justify-end',
          ]"
        >
          <button
            v-if="currentStep > 1"
            :class="[
              'cursor-pointer rounded px-2 py-1',
              'transition-all duration-300',
              'text-zinc-400 hover:text-zinc-200',
            ]"
            type="button"
            v-bind="backButtonProps"
            @click="handleBack"
          >
            {{ backButtonText }}
          </button>

          <button
            :class="[
              'flex items-center justify-center',
              'rounded px-4 py-2',
              'font-medium tracking-tight',
              'transition-all duration-300',
              'cursor-pointer',
              'disabled:cursor-not-allowed disabled:opacity-50',
              nextButtonClassName,
            ]"
            :disabled="!canProceed(currentStep)"
            :style="{
              backgroundColor: nextButtonColor,
              color: nextButtonTextColor,
            }"
            type="button"
            v-bind="nextButtonProps"
            @click="handleNext"
          >
            {{ nextButtonText }}
          </button>
        </div>
      </div>

      <div
        v-if="isLastStep && !isCompleted"
        :class="['px-8 pb-8', footerClassName]"
      >
        <div class="mt-8">
          <button
            v-if="currentStep > 1"
            :class="[
              'cursor-pointer rounded px-2 py-1',
              'transition-all duration-300',
              'text-zinc-400 hover:text-zinc-200',
            ]"
            type="button"
            v-bind="backButtonProps"
            @click="handleBack"
          >
            {{ backButtonText }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import {
  computed,
  ref,
  useSlots,
  type ButtonHTMLAttributes,
  type Component,
  type DirectiveBinding,
  type VNode,
} from "vue";
import { AnimatePresence, Motion } from "motion-v";

interface StepperProps {
  initialStep?: number;

  onStepChange?: (step: number) => void;
  onFinalStepCompleted?: () => void;

  canProceed?: (step: number) => boolean;
  completedSteps?: number[];

  stepCircleContainerClassName?: string;
  stepContainerClassName?: string;
  contentClassName?: string;
  footerClassName?: string;
  nextButtonClassName?: string;

  backButtonProps?: ButtonHTMLAttributes;
  nextButtonProps?: ButtonHTMLAttributes;

  backButtonText?: string;
  nextButtonText?: string;

  disableStepIndicators?: boolean;
  renderStepIndicator?: Component;

  borderColor?: string;

  indicatorActiveColor?: string;
  indicatorCompleteColor?: string;
  indicatorInactiveColor?: string;

  indicatorActiveTextColor?: string;
  indicatorInactiveTextColor?: string;
  indicatorCompleteTextColor?: string;

  dotColor?: string;
  checkColor?: string;

  lineBackgroundColor?: string;
  lineCompleteColor?: string;

  nextButtonColor?: string;
  nextButtonTextColor?: string;
}

const props = withDefaults(defineProps<StepperProps>(), {
  initialStep: 1,

  onStepChange: () => {},
  onFinalStepCompleted: () => {},

  canProceed: () => true,
  completedSteps: () => [],

  stepCircleContainerClassName: "",
  stepContainerClassName: "",
  contentClassName: "",
  footerClassName: "",
  nextButtonClassName: "",

  backButtonProps: () => ({}),
  nextButtonProps: () => ({}),

  backButtonText: "Back",
  nextButtonText: "Continue",

  disableStepIndicators: false,
  renderStepIndicator: undefined,

  borderColor: "transparent",

  indicatorActiveColor: "#27ff64",
  indicatorCompleteColor: "#27ff64",
  indicatorInactiveColor: "#222",

  indicatorActiveTextColor: "#27ff64",
  indicatorInactiveTextColor: "#a3a3a3",
  indicatorCompleteTextColor: "#1bbf4a",

  dotColor: "#000",
  checkColor: "#000",

  lineBackgroundColor: "#3f3f46",
  lineCompleteColor: "#27ff64",

  nextButtonColor: "#27ff64",
  nextButtonTextColor: "#000",
});

const slots = useSlots();

const currentStep = ref(props.initialStep);
const direction = ref(0);
const parentHeight = ref(0);

const stepsArray = computed<VNode[]>(() => {
  const nodes = slots.default?.() || [];

  return nodes.flatMap((node) =>
    node.type === Symbol.for("v-fgt") ? (node.children as VNode[]) : node,
  );
});

const totalSteps = computed(() => stepsArray.value.length);

const isLastStep = computed(() => currentStep.value === totalSteps.value);

const isCompleted = computed(() => currentStep.value > totalSteps.value);

const canProceed = (step: number) => {
  return props.canProceed(step);
};

type LayoutHeightHook = (
  el: HTMLElement,
  binding: DirectiveBinding<(height: number) => void>,
) => void;

const vLayoutHeight = {
  mounted(el, binding) {
    binding.value(el.offsetHeight);
  },

  updated(el, binding) {
    binding.value(el.offsetHeight);
  },
} as {
  mounted: LayoutHeightHook;
  updated: LayoutHeightHook;
};

const measureHeight = (height: number) => {
  parentHeight.value = height;
};

const getStepStatus = (step: number): "active" | "inactive" | "complete" => {
  if (props.completedSteps.includes(step)) {
    return "complete";
  }

  if (currentStep.value > step) {
    return "complete";
  }

  if (currentStep.value === step) {
    return "active";
  }

  return "inactive";
};

const updateStep = (step: number) => {
  currentStep.value = step;

  if (step > totalSteps.value) {
    props.onFinalStepCompleted();
    return;
  }

  props.onStepChange(step);
};

const handleBack = () => {
  if (currentStep.value <= 1) {
    return;
  }

  direction.value = -1;
  updateStep(currentStep.value - 1);
};

const handleNext = () => {
  if (!canProceed(currentStep.value)) {
    return;
  }

  if (isLastStep.value) {
    return;
  }

  direction.value = 1;
  updateStep(currentStep.value + 1);
};

const handleStepIndicatorClick = (step: number) => {
  if (
    step === currentStep.value ||
    props.disableStepIndicators ||
    step > currentStep.value
  ) {
    return;
  }

  direction.value = -1;
  updateStep(step);
};

const handleCustomStepClick = (step: number) => {
  if (step > currentStep.value) {
    return;
  }

  direction.value = -1;
  updateStep(step);
};

const indicatorVariants = computed(() => ({
  inactive: {
    scale: 1,
    backgroundColor: props.indicatorInactiveColor,
    color: props.indicatorInactiveTextColor,
  },

  active: {
    scale: 1,
    backgroundColor: props.indicatorActiveColor,
    color: props.indicatorActiveTextColor,
  },

  complete: {
    scale: 1,
    backgroundColor: props.indicatorCompleteColor,
    color: props.indicatorCompleteTextColor,
  },
}));

const lineVariants = {
  incomplete: {
    width: 0,
  },

  complete: {
    width: "100%",
  },
};

const stepVariants = {
  enter: (dir: number) => ({
    x: dir >= 0 ? "-100%" : "100%",
    opacity: 0,
  }),

  center: {
    x: "0%",
    opacity: 1,
  },

  exit: (dir: number) => ({
    x: dir >= 0 ? "50%" : "-50%",
    opacity: 0,
  }),
};
</script>

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional
from zoneinfo import ZoneInfo


@dataclass
class Ingredient:
    name: str
    quantity: int
    unit: str


@dataclass
class Meal:
    meal_type: str
    name: str
    protein: int
    calories: int
    portion: str
    alternatives: list[str]
    ingredients: list[Ingredient]


@dataclass
class DayPlan:
    day: str
    title: str
    meals: list[Meal]
    total_protein: int
    total_calories: int


@dataclass
class ShoppingItem:
    name: str
    quantity: int
    unit: str


@dataclass
class WeeklyPlan:
    target_protein: int
    days: list[DayPlan]
    shopping_items: list[ShoppingItem]


@dataclass
class MessageOptions:
    delivery_mode: str = "menu_only"
    customization_notes: str = ""
    next_day_only: bool = True
    timezone_name: str = "Asia/Dubai"


WEEKLY_TEMPLATE = [
    {
        "day": "Monday",
        "title": "Paneer + Soy Kickoff",
        "meals": [
            {
                "meal_type": "Breakfast",
                "name": "Besan chilla with paneer filling",
                "protein": 26,
                "calories": 420,
                "portion": "2 medium chillas with about 90g paneer filling",
                "alternatives": [
                    "2 moong dal chillas with paneer stuffing",
                    "1 bowl tofu bhurji with 2 small phulkas",
                ],
                "ingredients": [("Besan", 200, "g"), ("Paneer", 180, "g"), ("Onions", 1, "pc"), ("Tomatoes", 1, "pc")],
            },
            {
                "meal_type": "Lunch",
                "name": "Rajma quinoa bowl with cucumber raita",
                "protein": 27,
                "calories": 510,
                "portion": "1 large bowl rajma quinoa plus 1 small bowl raita",
                "alternatives": [
                    "1 large bowl chole brown rice with curd",
                    "1 paneer millet bowl with cucumber salad",
                ],
                "ingredients": [("Rajma", 220, "g cooked"), ("Quinoa", 90, "g dry"), ("Curd", 200, "g"), ("Cucumber", 1, "pc")],
            },
            {
                "meal_type": "Snack",
                "name": "Greek yogurt with roasted chana",
                "protein": 18,
                "calories": 220,
                "portion": "1 cup Greek yogurt with 1 small handful roasted chana",
                "alternatives": [
                    "1 glass chaas with 50g soy nuts",
                    "1 bowl hung curd dip with cucumber sticks",
                ],
                "ingredients": [("Greek yogurt", 250, "g"), ("Roasted chana", 50, "g")],
            },
            {
                "meal_type": "Dinner",
                "name": "Soy chunk bhurji with 2 multigrain rotis",
                "protein": 31,
                "calories": 460,
                "portion": "1 medium bowl bhurji with 2 rotis",
                "alternatives": [
                    "1 bowl tofu bhurji with 2 rotis",
                    "1 bowl paneer capsicum stir-fry with 2 small rotis",
                ],
                "ingredients": [("Soy chunks", 70, "g dry"), ("Whole wheat atta", 80, "g"), ("Capsicum", 1, "pc"), ("Onions", 1, "pc")],
            },
        ],
    },
    {
        "day": "Tuesday",
        "title": "Tofu + Dal Day",
        "meals": [
            {
                "meal_type": "Breakfast",
                "name": "Moong dal dosa with mint curd dip",
                "protein": 24,
                "calories": 360,
                "portion": "2 dosas with 1 small bowl mint curd",
                "alternatives": [
                    "2 pesarattu with chutney",
                    "1 bowl sprouts chaat with buttermilk",
                ],
                "ingredients": [("Moong dal", 120, "g dry"), ("Curd", 150, "g"), ("Mint", 1, "bunch")],
            },
            {
                "meal_type": "Lunch",
                "name": "Tofu tikka rice bowl",
                "protein": 29,
                "calories": 500,
                "portion": "1 large bowl with about 200g tofu",
                "alternatives": [
                    "1 paneer tikka rice bowl",
                    "1 bowl soy keema with jeera rice",
                ],
                "ingredients": [("Tofu", 250, "g"), ("Brown rice", 90, "g dry"), ("Capsicum", 1, "pc"), ("Curd", 100, "g")],
            },
            {
                "meal_type": "Snack",
                "name": "Protein buttermilk and peanuts",
                "protein": 14,
                "calories": 210,
                "portion": "1 large glass buttermilk with 1 small handful peanuts",
                "alternatives": [
                    "1 glass salted lassi with roasted chana",
                    "1 cup milk with 25g almonds",
                ],
                "ingredients": [("Buttermilk", 400, "ml"), ("Peanuts", 40, "g")],
            },
            {
                "meal_type": "Dinner",
                "name": "Dal palak with paneer salad",
                "protein": 34,
                "calories": 480,
                "portion": "1 medium bowl dal palak plus 1 side paneer salad",
                "alternatives": [
                    "1 bowl dal makhani with tofu salad",
                    "1 bowl mixed dal with paneer cubes",
                ],
                "ingredients": [("Toor dal", 100, "g dry"), ("Spinach", 200, "g"), ("Paneer", 150, "g"), ("Tomatoes", 1, "pc")],
            },
        ],
    },
    {
        "day": "Wednesday",
        "title": "Curd + Chickpea Balance",
        "meals": [
            {
                "meal_type": "Breakfast",
                "name": "Hung curd parfait with chia and seeds",
                "protein": 23,
                "calories": 310,
                "portion": "1 parfait jar or 1 medium bowl",
                "alternatives": [
                    "1 bowl Greek yogurt with oats and seeds",
                    "1 bowl dahi chia pudding",
                ],
                "ingredients": [("Hung curd", 250, "g"), ("Chia seeds", 20, "g"), ("Mixed seeds", 25, "g")],
            },
            {
                "meal_type": "Lunch",
                "name": "Chole with millet roti",
                "protein": 28,
                "calories": 520,
                "portion": "1 medium bowl chole with 2 millet rotis",
                "alternatives": [
                    "1 bowl kala chana curry with 2 rotis",
                    "1 bowl rajma with 2 jowar rotis",
                ],
                "ingredients": [("Chole", 240, "g cooked"), ("Bajra flour", 90, "g"), ("Onions", 1, "pc"), ("Tomatoes", 1, "pc")],
            },
            {
                "meal_type": "Snack",
                "name": "Masala edamame chaat",
                "protein": 17,
                "calories": 200,
                "portion": "1 medium bowl chaat",
                "alternatives": [
                    "1 bowl sprouts chaat",
                    "1 bowl boiled chana salad",
                ],
                "ingredients": [("Edamame", 180, "g"), ("Tomatoes", 1, "pc"), ("Onions", 1, "pc")],
            },
            {
                "meal_type": "Dinner",
                "name": "Paneer bhurji with sauteed veggies",
                "protein": 33,
                "calories": 430,
                "portion": "1 bowl paneer bhurji with 1 side of sauteed vegetables",
                "alternatives": [
                    "1 bowl tofu bhurji with vegetables",
                    "1 bowl paneer peas masala with salad",
                ],
                "ingredients": [("Paneer", 220, "g"), ("Capsicum", 1, "pc"), ("Mushrooms", 150, "g"), ("Spinach", 100, "g")],
            },
        ],
    },
    {
        "day": "Thursday",
        "title": "Sattu + Lentil Build",
        "meals": [
            {
                "meal_type": "Breakfast",
                "name": "Sattu smoothie with milk and peanut butter",
                "protein": 24,
                "calories": 350,
                "portion": "1 large glass smoothie",
                "alternatives": [
                    "1 large glass banana sattu shake",
                    "1 glass milk smoothie with oats and chia",
                ],
                "ingredients": [("Sattu", 70, "g"), ("Milk", 350, "ml"), ("Peanut butter", 25, "g")],
            },
            {
                "meal_type": "Lunch",
                "name": "Mixed dal khichdi with curd",
                "protein": 26,
                "calories": 500,
                "portion": "1 large bowl khichdi with 1 small bowl curd",
                "alternatives": [
                    "1 bowl quinoa khichdi with curd",
                    "1 bowl dalia khichdi with paneer cubes",
                ],
                "ingredients": [("Mixed dal", 120, "g dry"), ("Rice", 70, "g dry"), ("Curd", 200, "g"), ("Carrots", 2, "pc")],
            },
            {
                "meal_type": "Snack",
                "name": "Paneer cubes with black salt",
                "protein": 18,
                "calories": 180,
                "portion": "100g paneer cubes",
                "alternatives": [
                    "100g tofu cubes with chaat masala",
                    "1 bowl hung curd dip with vegetable sticks",
                ],
                "ingredients": [("Paneer", 100, "g")],
            },
            {
                "meal_type": "Dinner",
                "name": "Tofu matar masala with 2 phulkas",
                "protein": 34,
                "calories": 470,
                "portion": "1 bowl tofu matar with 2 phulkas",
                "alternatives": [
                    "1 bowl paneer matar with 2 phulkas",
                    "1 bowl soy chunk curry with 2 rotis",
                ],
                "ingredients": [("Tofu", 250, "g"), ("Green peas", 180, "g"), ("Whole wheat atta", 80, "g"), ("Onions", 1, "pc")],
            },
        ],
    },
    {
        "day": "Friday",
        "title": "Sprouts + Soy Reset",
        "meals": [
            {
                "meal_type": "Breakfast",
                "name": "Sprouts poha with peanuts",
                "protein": 21,
                "calories": 390,
                "portion": "1 large bowl poha",
                "alternatives": [
                    "1 bowl sprouts upma",
                    "2 vegetable besan chillas",
                ],
                "ingredients": [("Mixed sprouts", 220, "g"), ("Poha", 70, "g dry"), ("Peanuts", 35, "g")],
            },
            {
                "meal_type": "Lunch",
                "name": "Paneer tikka wrap with hummus",
                "protein": 31,
                "calories": 530,
                "portion": "2 medium wraps",
                "alternatives": [
                    "2 tofu tikka wraps",
                    "1 paneer roll with yogurt dip and salad",
                ],
                "ingredients": [("Paneer", 200, "g"), ("Whole wheat wraps", 2, "pc"), ("Hummus", 80, "g"), ("Lettuce", 1, "head")],
            },
            {
                "meal_type": "Snack",
                "name": "Salted lassi with roasted soy nuts",
                "protein": 16,
                "calories": 220,
                "portion": "1 glass lassi with 1 small handful soy nuts",
                "alternatives": [
                    "1 glass chaas with roasted chana",
                    "1 cup curd with mixed seeds",
                ],
                "ingredients": [("Curd", 250, "g"), ("Soy nuts", 35, "g")],
            },
            {
                "meal_type": "Dinner",
                "name": "Soy keema with cauliflower rice",
                "protein": 35,
                "calories": 420,
                "portion": "1 bowl soy keema with 1 bowl cauliflower rice",
                "alternatives": [
                    "1 bowl tofu keema with vegetable rice",
                    "1 bowl soy chunk curry with sauteed vegetables",
                ],
                "ingredients": [("Soy chunks", 80, "g dry"), ("Cauliflower", 1, "head"), ("Green peas", 100, "g"), ("Tomatoes", 1, "pc")],
            },
        ],
    },
    {
        "day": "Saturday",
        "title": "Weekend Comfort, Still High Protein",
        "meals": [
            {
                "meal_type": "Breakfast",
                "name": "Oats dosa with paneer stuffing",
                "protein": 25,
                "calories": 410,
                "portion": "2 dosas with paneer stuffing",
                "alternatives": [
                    "2 ragi dosas with paneer filling",
                    "1 bowl oats upma with curd",
                ],
                "ingredients": [("Oats", 80, "g"), ("Paneer", 180, "g"), ("Curd", 80, "g")],
            },
            {
                "meal_type": "Lunch",
                "name": "Kala chana salad bowl with tofu",
                "protein": 30,
                "calories": 470,
                "portion": "1 large salad bowl",
                "alternatives": [
                    "1 rajma tofu salad bowl",
                    "1 chickpea paneer salad bowl",
                ],
                "ingredients": [("Kala chana", 220, "g cooked"), ("Tofu", 200, "g"), ("Cucumber", 1, "pc"), ("Tomatoes", 1, "pc")],
            },
            {
                "meal_type": "Snack",
                "name": "Protein chai with milk and almonds",
                "protein": 13,
                "calories": 190,
                "portion": "1 large cup chai with 8 to 10 almonds",
                "alternatives": [
                    "1 cup masala milk with almonds",
                    "1 cup coffee with milk and roasted chana",
                ],
                "ingredients": [("Milk", 300, "ml"), ("Almonds", 30, "g")],
            },
            {
                "meal_type": "Dinner",
                "name": "Palak paneer with dal soup",
                "protein": 34,
                "calories": 500,
                "portion": "1 medium bowl palak paneer with 1 cup dal soup",
                "alternatives": [
                    "1 bowl palak tofu with dal soup",
                    "1 bowl paneer saag with mixed dal",
                ],
                "ingredients": [("Paneer", 200, "g"), ("Spinach", 250, "g"), ("Moong dal", 80, "g dry"), ("Onions", 1, "pc")],
            },
        ],
    },
    {
        "day": "Sunday",
        "title": "Prep-Friendly Finish",
        "meals": [
            {
                "meal_type": "Breakfast",
                "name": "Overnight oats with Greek yogurt",
                "protein": 24,
                "calories": 340,
                "portion": "1 jar or 1 medium bowl",
                "alternatives": [
                    "1 bowl yogurt oats parfait",
                    "1 bowl muesli with Greek yogurt",
                ],
                "ingredients": [("Oats", 70, "g"), ("Greek yogurt", 250, "g"), ("Chia seeds", 20, "g")],
            },
            {
                "meal_type": "Lunch",
                "name": "Paneer pulao with cucumber raita",
                "protein": 28,
                "calories": 520,
                "portion": "1 medium plate pulao with 1 small bowl raita",
                "alternatives": [
                    "1 tofu pulao with raita",
                    "1 peas paneer rice bowl with curd",
                ],
                "ingredients": [("Paneer", 180, "g"), ("Rice", 90, "g dry"), ("Curd", 200, "g"), ("Cucumber", 1, "pc")],
            },
            {
                "meal_type": "Snack",
                "name": "Roasted makhana and soy nuts",
                "protein": 14,
                "calories": 210,
                "portion": "1 medium bowl mix",
                "alternatives": [
                    "1 bowl roasted chana and peanuts",
                    "1 bowl fox nuts with almonds",
                ],
                "ingredients": [("Makhana", 35, "g"), ("Soy nuts", 30, "g")],
            },
            {
                "meal_type": "Dinner",
                "name": "Dal makhani with tofu salad",
                "protein": 36,
                "calories": 510,
                "portion": "1 medium bowl dal makhani with 1 side tofu salad",
                "alternatives": [
                    "1 bowl mixed dal with paneer salad",
                    "1 bowl rajma dal with tofu salad",
                ],
                "ingredients": [("Whole urad dal", 100, "g dry"), ("Rajma", 80, "g dry"), ("Tofu", 220, "g"), ("Onions", 1, "pc")],
            },
        ],
    },
]


def build_plan(target_protein: int = 100) -> WeeklyPlan:
    scale = target_protein / 100
    days: list[DayPlan] = []

    for day_data in WEEKLY_TEMPLATE:
        meals: list[Meal] = []
        for meal_data in day_data["meals"]:
            scaled_protein = round(meal_data["protein"] * scale)
            ingredient_scale = scaled_protein / meal_data["protein"] if meal_data["protein"] else 1
            meal_ingredients = [
                Ingredient(
                    name=item_name,
                    quantity=round_quantity(quantity * ingredient_scale, unit),
                    unit=unit,
                )
                for item_name, quantity, unit in meal_data["ingredients"]
            ]
            meals.append(
                Meal(
                    meal_type=meal_data["meal_type"],
                    name=meal_data["name"],
                    protein=scaled_protein,
                    calories=meal_data["calories"],
                    portion=meal_data["portion"],
                    alternatives=meal_data["alternatives"],
                    ingredients=meal_ingredients,
                )
            )

        days.append(
            DayPlan(
                day=day_data["day"],
                title=day_data["title"],
                meals=meals,
                total_protein=sum(meal.protein for meal in meals),
                total_calories=sum(meal.calories for meal in meals),
            )
        )

    return WeeklyPlan(target_protein=target_protein, days=days, shopping_items=aggregate_ingredients(days))


def aggregate_ingredients(days: list[DayPlan]) -> list[ShoppingItem]:
    totals: dict[tuple[str, str], int] = {}
    for day in days:
        for meal in day.meals:
            for ingredient in meal.ingredients:
                key = (ingredient.name, ingredient.unit)
                totals[key] = round_quantity(totals.get(key, 0) + ingredient.quantity, ingredient.unit)

    return [
        ShoppingItem(name=name, quantity=quantity, unit=unit)
        for (name, unit), quantity in sorted(totals.items(), key=lambda item: item[0][0].lower())
    ]


def build_whatsapp_message(plan: WeeklyPlan) -> str:
    return build_whatsapp_message_with_options(plan, MessageOptions())


def build_whatsapp_message_with_options(plan: WeeklyPlan, options: MessageOptions) -> str:
    if options.next_day_only:
        day = get_next_day_plan(plan, options.timezone_name)
        selected_meals = select_delivery_meals(day)
        total_protein = sum(meal.protein for meal in selected_meals)
        total_calories = sum(meal.calories for meal in selected_meals)
        header = [
            f"Tomorrow's meal plan for {day.day}",
            f"Protein target: {plan.target_protein}g/day",
            f"Estimated total for tomorrow: {total_protein}g protein, about {total_calories} kcal",
            "",
        ]
        if options.customization_notes:
            header.append(f"Note: {options.customization_notes}")
            header.append("")

        lines = []
        for meal in selected_meals:
            lines.append(
                f"{meal.meal_type}: {meal.name}"
            )
            lines.append(f"Portion: {meal.portion}")
            lines.append(f"Nutrition: about {meal.protein}g protein, {meal.calories} kcal")
            lines.append("Alternatives:")
            lines.append(f"1. {meal.alternatives[0]}")
            lines.append(f"2. {meal.alternatives[1]}")
            lines.append("")

        ingredient_line = ", ".join(
            f"{ingredient.name} {ingredient.quantity} {ingredient.unit}"
            for ingredient in aggregate_selected_ingredients(selected_meals)
        )
        lines.append(f"Ingredients for preparation: {ingredient_line}")

        return "\n".join(header + lines).strip()

    average_protein = round(sum(day.total_protein for day in plan.days) / len(plan.days))
    header = [
        "Your weekly Indian vegetarian protein plan is ready.",
        f"Target: {plan.target_protein}g protein/day",
        f"Weekly average: {average_protein}g/day",
        "",
    ]

    if options.customization_notes:
        header.insert(3, f"Note: {options.customization_notes}")

    day_lines: list[str] = []
    for day in plan.days:
        day_lines.append(f"{day.day} ({day.total_protein}g, ~{day.total_calories} kcal)")
        for meal in day.meals:
            day_lines.append(
                f"- {meal.meal_type}: {meal.name} | {meal.portion} | {meal.protein}g protein | {meal.calories} kcal"
            )
        day_lines.append("")

    return "\n".join(header + day_lines)


def get_next_day_plan(plan: WeeklyPlan, timezone_name: str) -> DayPlan:
    timezone = ZoneInfo(timezone_name)
    tomorrow_name = (datetime.now(timezone) + timedelta(days=1)).strftime("%A")
    for day in plan.days:
        if day.day == tomorrow_name:
            return day
    return plan.days[0]


def select_delivery_meals(day: DayPlan) -> list[Meal]:
    big_meals = [meal for meal in day.meals if meal.meal_type in {"Lunch", "Dinner"}]
    snack_meals = [meal for meal in day.meals if meal.meal_type == "Snack"]

    if len(big_meals) < 2:
        non_snack = [meal for meal in day.meals if meal.meal_type != "Snack"]
        big_meals = non_snack[:2]

    if not snack_meals:
        remaining = [meal for meal in day.meals if meal not in big_meals]
        snack_meals = remaining[:1]

    return big_meals[:2] + snack_meals[:1]


def aggregate_selected_ingredients(meals: list[Meal]) -> list[Ingredient]:
    totals: dict[tuple[str, str], int] = {}
    for meal in meals:
        for ingredient in meal.ingredients:
            key = (ingredient.name, ingredient.unit)
            totals[key] = round_quantity(totals.get(key, 0) + ingredient.quantity, ingredient.unit)

    return [
        Ingredient(name=name, quantity=quantity, unit=unit)
        for (name, unit), quantity in sorted(totals.items(), key=lambda item: item[0][0].lower())
    ]


def round_quantity(value: float, unit: str) -> int:
    if unit in {"pc", "head", "bunch"}:
        return max(1, round(value))
    return round(value)

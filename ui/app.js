const { createApp } = Vue;

createApp({
  data() {
    return {
      devMode: false,
      visible: false,
      showInput: false,
      style: {
        fontSize: 'm',
        descriptionsidebar: null
      },
      desc: {
        data: null,
        show: false
      },
      job: null,
      language: {},
      labels: {},
      location: {},
      categories: [],
      consumables: {},
      currentRoute: 'home',
      activeCraftable: null,
      quantity: 1,
      min: 1,
      max: 10,
      crafttime: 15000,
      testData: [
        {
          Text: "Meat Bfast ",
          SubText: "InvMax = 10",
          Desc: "Recipe: 1x Apple, 1x Water, 1x Sugar, 1x Egg, 1x Flour",
          Items: [
              {
                  name: "meat",
                  count: 1
              },
              {
                  name: "salt",
                  count: 1
              }
          ],
          Reward: [
              {
                  name: "consumable_breakfast",
                  count: 1
              }
          ],
          Job: 0, 
          Location: 0,
          Category: "food"
        }
      ],
      testCategory: [
        {
          ident: 'food', 
          text: 'Craft Food',
          Job: 0,
          Location: 0
        }
      ]
    };
  },
  mounted() {
    // Window Event Listeners
    window.addEventListener("message", this.onMessage);
    window.addEventListener("keydown", this.onKeypress)

    // Debug only
    if (this.devMode) {
      let devData = {
        craftables: this.testData,
        categories: this.testCategory,
        crafttime: 15000,
        style: {
          fontSize: 'm',
          descriptionsidebar: true
        },
        language: {
          InputHeader: 'How many {{msg}} you want to craft',
          InputCraft: 'Craft Item',
          InputCancel: 'Cancel',
          BackButton: 'Back',
          ExitButton: 'Exit',
          CraftHeader: 'Crafting',
          CraftText: 'Press [~e~G~q~] to Craft',
          InvalidAmount: 'Invalid Amount',
          Crafting: 'Crafting...',
          FinishedCrafting: 'You finished crafting',
          PlaceFire: "You're placing a campfire...",
          PutOutFire: 'Putting out the campfire...',
          NotEnough: 'Not enough material for this recipe',
          NotJob: 'You dont have the required job '
        }
      }
      this.setData(devData)
      this.visible = true
    }
  },
  destroyed() {
    // Remove listeners when UI is destroyed to save on memory
    window.removeEventListener("message");
    window.removeEventListener('keydown')
  },
  computed: {
    fontClass() {
      let fontc = {}
      switch (this.style.fontSize) {
        case 's': fontc['smallfont']  = true; break;
        case 'm': fontc['mediumfont'] = true; break;
        case 'l': fontc['largefont']  = true; break;
        default: break;
      }
      return fontc
    },
    InputCraftText() {
      const base  = this.language.InputHeader || '';
      const title = this.activeCraftable ? this.displayName(this.activeCraftable) : '';
      return base.replace('{{msg}}', title);
    },
    IngredientEntries() {
      if (!this.desc.show || !this.desc.data) return [];
      const it = this.desc.data;

      if (Array.isArray(it.Items) && it.Items.length > 0) {
        return it.Items.map(x => {
          const key   = (x.name || '').trim();
          const count = Number(x.count || 1);
          return {
            key,
            label: this.labelOf(key),
            count,
            img: this.getItemImg(key)
          };
        });
      }
      return [];
    },
  },
  methods: {
    getItemImg(name) {
      return `nui://vorp_inventory/html/img/items/${name}.png`;
    },
    labelOf(name) {
      if (!name) return '';
      const k = String(name).toLowerCase();
      return this.labels?.[k]?.label || name;
    },
    limitOf(name) {
      if (!name) return null;
      const k = String(name).toLowerCase();
      const lim = this.labels?.[k]?.limit;
      return (typeof lim === 'number') ? lim : null;
    },
    rewardName(recipe) {
      if (!recipe || !Array.isArray(recipe.Reward) || recipe.Reward.length === 0) return '';
      return recipe.Reward[0].name || '';
    },
    displayName(recipe) {
      const rn = this.rewardName(recipe);
      return this.labelOf(rn) || rn;
    },
    onMessage(event) {
      switch(event.data.type) {
        case "vorp-craft-open":
          this.setData(event.data)
          this.visible = true;
          break;
        case "vorp-craft-animate":
          this.animationPlaying()
          break;
        default:
          break;
      }
    },
    onKeypress(event) {
      if (event.key === "I" || event.key === "i") {
        fetch(`https://${GetParentResourceName()}/vorp-openinv`, {
          method: 'POST'
        })
      }

      if (event.key === "Escape" || event.key === "esc") {
        this.currentRoute = 'home'
        this.closeView()
      }
    },
    toggleDesc(ing, state) {
      this.desc.show = state
      this.desc.data = ing
    },
    animationPlaying() {
      this.visible = false
        
      setTimeout(()=>{
        this.visible = true
      }, this.crafttime);
    },
    craftItem() {
      fetch(`https://${GetParentResourceName()}/vorp-craftevent`, {
        method: 'POST',
        body: JSON.stringify({
          craftable: this.activeCraftable,
          quantity: this.quantity,
          location: this.location
        })
      }).then(resp => resp.json()).then(resp => {
        this.showInput = false
        this.activeCraftable = null
        this.quantity = 1
      }).catch(function (error) {
        console.warn(error);
      })
    },
    handleItemClick(data) {
      this.activeCraftable = data
      this.showInput = true
    },
    formatQuantity() {
      if (this.quantity <= this.min - 1) {
          this.quantity = this.min
      }

      if (this.quantity > this.max) {
          this.quantity = this.max
      }
    },
    increase() {
        let value = this.quantity
        value = isNaN(value) ? this.min : value;

        if (value >= this.max) {
            value = this.max - 1
        }

        value++;
        this.quantity = value
    },
    decrease() {
        let value = this.quantity
        value = isNaN(value) ? this.min : value;
        value < this.min ? value = this.min : '';
        value--;
        value < this.min ? value = this.min : '';
        this.quantity = value
    },
    closeView() {
      this.showInput = false;
      this.activeCraftable = null;
      this.desc.show = false;
      this.currentRoute = 'home';
      this.visible = false;

      fetch(`https://${GetParentResourceName()}/vorp-craft-close`, {
        method: 'POST'
      })
    },
    setData(data) {
      const craftables = data.craftables || [];
      const categories = data.categories || [];
      const crafttime  = data.crafttime;
      const style      = data.style || {};
      const language   = data.language || {};
      const location   = data.location || {};
      const charJob    = data.job;
      const labels     = data.labels || data.LabelsLUT || {};
      const consumables = {};
      const filteredcat = [];

      // Setup categories buckets
      categories.forEach(cat => {
        consumables[cat.ident] = [];
        const jobcheck = cat.Job === 0 ? true : cat.Job.some(j => j === charJob);

        if (jobcheck) {
          if (cat.Location == 0) {
            filteredcat.push(cat);
          } else {
            const l = cat.Location.length;
            for (let pos = 0; pos < l; pos++) {
              const loc = cat.Location[pos];
              if (loc == location?.id) {
                filteredcat.push(cat);
                break;
              }
            }
          }
        }
      });

      // Fill buckets with craftables
      craftables.forEach(item => {
        const jobcheck = item.Job === 0 ? true : item.Job.some(j => j === charJob);

        if (jobcheck) {
          if (item.Location == 0) {
            if (consumables[item.Category]) {
              consumables[item.Category].push(item);
            }
          } else {
            const l = item.Location.length;
            for (let pos = 0; pos < l; pos++) {
              const loc = item.Location[pos];
              if (loc == location?.id) {
                if (consumables[item.Category]) {
                  consumables[item.Category].push(item);
                }
                break;
              }
            }
          }
        }
      });

      this.language    = language;
      this.labels      = labels;
      this.consumables = consumables;
      this.categories  = filteredcat;
      this.crafttime   = crafttime;
      this.style       = style;
      this.location    = location;
    },
  },
}).mount("#app");
